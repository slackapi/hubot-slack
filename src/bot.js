const {Adapter, TextMessage, EnterMessage, LeaveMessage, TopicMessage, CatchAllMessage}  = require.main.require("hubot/es2015.js");
const {SlackTextMessage, ReactionMessage, PresenceMessage, FileSharedMessage, MeMessage} = require("./message");

const {RtmClient, WebClient} = require("@slack/client");
const pkg = require("../package.json");

class SlackClient {
  static CONVERSATION_CACHE_TTL_MS =
    process.env.HUBOT_SLACK_CONVERSATION_CACHE_TTL_MS
    ? parseInt(process.env.HUBOT_SLACK_CONVERSATION_CACHE_TTL_MS, 10)
    : (5 * 60 * 1000);
  constructor(options, robot) {
    this.robot = robot;
    this.rtm = new RtmClient(options.token, options.rtm);
    this.web = new WebClient(options.token, { maxRequestConcurrency: 1, logLevel: 'error'});
    this.apiPageSize = 100;
    if (!isNaN(options.apiPageSize)) {
      this.apiPageSize = parseInt(options.apiPageSize, 10);
    }

    this.robot.logger.debug(`RtmClient initialized with options: ${JSON.stringify(options.rtm)}`);
    this.rtmStartOpts = options.rtmStart || {};

    // Map to convert bot user IDs (BXXXXXXXX) to user representations for events from custom
    // integrations and apps without a bot user
    this.botUserIdMap = {
      "B01": { id: "B01", user_id: "USLACKBOT" }
    };

    // Map to convert conversation IDs to conversation representations
    this.channelData = {};

    // Event handling
    // NOTE: add channel join and leave events
    this.rtm.on("message", this.eventWrapper, this);
    this.rtm.on("reaction_added", this.eventWrapper, this);
    this.rtm.on("reaction_removed", this.eventWrapper, this);
    this.rtm.on("presence_change", this.eventWrapper, this);
    this.rtm.on("member_joined_channel", this.eventWrapper, this);
    this.rtm.on("member_left_channel", this.eventWrapper, this);
    this.rtm.on("file_shared", this.eventWrapper, this);
    this.rtm.on("user_change", this.updateUserInBrain, this);
    this.eventHandler = undefined;
  }

  connect() {
    this.robot.logger.debug(`RtmClient#start() with options: ${JSON.stringify(this.rtmStartOpts)}`);
    return this.rtm.start(this.rtmStartOpts);
  }
  onEvent(callback) {
    if (this.eventHandler !== callback) { return this.eventHandler = callback; }
  }

  disconnect() {
    this.rtm.disconnect();
    return this.rtm.removeAllListeners();
  }

  setTopic(conversationId, topic) {
    this.robot.logger.debug(`SlackClient#setTopic() with topic ${topic}`);
    return this.web.conversations.info(conversationId)
      .then(res => {
        const conversation = res.channel;
        if (!conversation.is_im && !conversation.is_mpim) {
          return this.web.conversations.setTopic(conversationId, topic);
        } else {
          return this.robot.logger.debug(`Conversation ${conversationId} is a DM or MPDM. ` +
                              "These conversation types do not have topics."
          );
        }
    }).catch(error => {
        return this.robot.logger.error(`Error setting topic in conversation ${conversationId}: ${error.message}`);
    });
  }
  send(envelope, message) {
    const room = envelope.room || envelope.id;
    if ((room == null)) {
      this.robot.logger.error("Cannot send message without a valid room. Envelopes should contain a room property set to " +
                          "a Slack conversation ID."
      );
      return;
    }
    this.robot.logger.debug(`SlackClient#send() room: ${room}, message: ${message}`);
    const options = {
      as_user: true,
      link_names: 1,
      thread_ts: (envelope.message != null ? envelope.message.thread_ts : undefined)
    };
    if (typeof message !== "string") {
      return this.web.chat.postMessage(room, message.text, Object.assign(message, options))
        .catch(error => {
          return this.robot.logger.error(`SlackClient#send() error: ${error.message}`);
      });
    } else {
      return this.web.chat.postMessage(room, message, options)
        .catch(error => {
          return this.robot.logger.error(`SlackClient#send() error: ${error.message}`);
      });
    }
  }
  loadUsers(callback) {
    const combinedResults = { members: [] };
    var pageLoaded = (error, results) => {
      if (error) { return callback(error); }
      for (var member of results.members) { combinedResults.members.push(member); }

      if(results?.response_metadata?.next_cursor) {
        return this.web.users.list({
          limit: this.apiPageSize,
          cursor: results.response_metadata.next_cursor
        }, pageLoaded);
      } else {
        return callback(null, combinedResults);
      }
    };
    return this.web.users.list({ limit: this.apiPageSize }, pageLoaded);
  }

  fetchUser(userId) {
    if (this.robot.brain.data.users[userId] != null) { return Promise.resolve(this.robot.brain.data.users[userId]); }
    return this.web.users.info(userId).then(r => this.updateUserInBrain(r.user));
  }
  fetchBotUser(botId) {
    if (this.botUserIdMap[botId] != null) { return Promise.resolve(this.botUserIdMap[botId]); }
    this.robot.logger.debug(`SlackClient#fetchBotUser() Calling bots.info API for bot_id: ${botId}`);
    return this.web.bots.info({bot: botId}).then(r => r.bot);
  }
  fetchConversation(conversationId) {
    const expiration = Date.now() - SlackClient.CONVERSATION_CACHE_TTL_MS;
    if (((this.channelData[conversationId] != null ? this.channelData[conversationId].channel : undefined) != null) &&
      (expiration < (this.channelData[conversationId] != null ? this.channelData[conversationId].updated : undefined))) { return Promise.resolve(this.channelData[conversationId].channel); }
    if (this.channelData[conversationId] != null) { delete this.channelData[conversationId]; }
    return this.web.conversations.info(conversationId).then(r => {
      if (r.channel != null) {
        this.channelData[conversationId] = {
          channel: r.channel,
          updated: Date.now()
        };
      }
      return r.channel;
    });
  }
  updateUserInBrain(event_or_user) {
    let key, value;
    const user = event_or_user.type === 'user_change' ? event_or_user.user : event_or_user;
    const newUser = {
      id: user.id,
      name: user.name,
      real_name: user.real_name,
      slack: {}
    };
    if ((user.profile != null ? user.profile.email : undefined) != null) { newUser.email_address = user.profile.email; }
    for (key in user) {
      value = user[key];
      newUser.slack[key] = value;
    }
    if (user.id in this.robot.brain.data.users) {
      for (key in this.robot.brain.data.users[user.id]) {
        value = this.robot.brain.data.users[user.id][key];
        if (!(key in newUser)) {
          newUser[key] = value;
        }
      }
    }
    delete this.robot.brain.data.users[user.id];
    return this.robot.brain.userForId(user.id, newUser);
  }
  eventWrapper(event) {
    if (this.eventHandler) {
      const fetches = {};
      if (event.user) {
        fetches.user = this.fetchUser(event.user);
      } else if (event.bot_id) {
        fetches.bot = this.fetchBotUser(event.bot_id);
      }

      if (event.item_user) {
        fetches.item_user = this.fetchUser(event.item_user);
      }
      return Promise.props(fetches)
        .then(fetched => {
          if (fetched.item_user) { event.item_user = fetched.item_user; }
          if (fetched.user) {
            event.user = fetched.user;
          } else if (fetched.bot) {
            if (this.botUserIdMap[event.bot_id]) {
              event.user = fetched.bot;
            } else if (fetched.bot.user_id != null) {
              return this.web.users.info(fetched.bot.user_id).then(res => {
                event.user = res.user;
                this.botUserIdMap[event.bot_id] = res.user;
                return event;
              });
            } else {
              this.botUserIdMap[event.bot_id] = false;
              event.user = {};
            }
          } else {
            event.user = {};
          }
          return event;
      }).then(fetchedEvent => {
          try { return this.eventHandler(fetchedEvent); }
          catch (error) { return this.robot.logger.error(`An error occurred while processing an RTM event: ${error.message}.`); }
        }).catch(error => {
          return this.robot.logger.error(`Incoming RTM message dropped due to error fetching info for a property: ${error.message}.`);
      });
    }
  }
}

if (SlackClient.CONVERSATION_CACHE_TTL_MS === NaN) {
  throw new Error('HUBOT_SLACK_CONVERSATION_CACHE_TTL_MS must be a number. It could not be parsed.');
}

class SlackBot extends Adapter {
  constructor(robot, options) {
    super(robot);
    this.options = options;
    this.robot.logger.info(`hubot-slack adapter v${pkg.version}`);
    this.client = new SlackClient(this.options, this.robot);
  }
  run() {
    if (!this.options.token) {
      return this.robot.logger.error("No token provided to Hubot");
    }
    const needle = this.options.token.substring(0, 5);
    if (!["xoxb-", "xoxp-"].includes(needle)) {
      return this.robot.logger.error("Invalid token provided, please follow the upgrade instructions");
    }
    this.client.rtm.on("open", this.open.bind(this));
    this.client.rtm.on("close", this.close.bind(this));
    this.client.rtm.on("disconnect", this.disconnect.bind(this));
    this.client.rtm.on("error", this.error.bind(this));
    this.client.rtm.on("authenticated", this.authenticated.bind(this));
    this.client.onEvent(this.eventHandler.bind(this));

    // TODO: set this to false as soon as RTM connection closes (even if reconnect will happen later)
    // TODO: check this value when connection finishes (even if its a reconnection)
    // TODO: build a map of enterprise users and local users
    this.needsUserListSync = true;
    if (!this.options.disableUserSync) {
      // Synchronize workspace users to brain
      this.client.loadUsers(this.usersLoaded.bind(this));
    } else {
      this.brainIsLoaded = true;
    }

    // Brain will emit 'loaded' the first time it connects to its storage and then again each time a key is set
    this.robot.brain.on("loaded", () => {
      if (!this.brainIsLoaded) {
        this.brainIsLoaded = true;
        // The following code should only run after the first time the brain connects to its storage

        // There's a race condition where the connection can happen after the above `@client.loadUsers` call finishes,
        // in which case the calls to save users in `@usersLoaded` would not persist. It is still necessary to call the
        // method there in the case Hubot is running without brain storage.
        // NOTE: is this actually true? won't the brain have the users in memory and persist to storage as soon as the
        // connection is complete?
        // NOTE: this seems wasteful. when there is brain storage, it will end up loading all the users twice.
        this.client.loadUsers(this.usersLoaded.bind(this));
        this.isLoaded = true;
        // NOTE: will this only subscribe a partial user list because loadUsers has not yet completed? it will at least
        // subscribe to the users that were stored in the brain from the last run.
        return this.presenceSub();
      }
    });

    // Start logging in
    return this.client.connect();
  }

  /**
   * Hubot is sending a message to Slack
   *
   * @public
   * @param {Object} envelope - fully documented in SlackClient
   * @param {...(string|Object)} messages - fully documented in SlackClient
   */
  send(envelope, ...messages) {
    let callback = function() {};
    if (typeof(messages[messages.length - 1]) === "function") {
      callback = messages.pop();
    }
    const messagePromises = messages.map(message => {
      if (typeof(message) === "function") { return Promise.resolve(); }
      // NOTE: perhaps do envelope manipulation here instead of in the client (separation of concerns)
      if (message !== "") { return this.client.send(envelope, message); }
    });
    return Promise.all(messagePromises).then(callback.bind(null, null), callback);
  }

  /**
   * Hubot is replying to a Slack message
   * @public
   * @param {Object} envelope - fully documented in SlackClient
   * @param {...(string|Object)} messages - fully documented in SlackClient
   */
  reply(envelope, ...messages) {
    let callback = function() {};
    if (typeof(messages[messages.length - 1]) === "function") {
      callback = messages.pop();
    }
    const messagePromises = messages.map(message => {
      if (typeof(message) === "function") { 
        return Promise.resolve();
      }

      if (message !== "") {
        // TODO: channel prefix matching should be removed
        if (envelope.room[0] !== "D") { message = `<@${envelope.user.id}>: ${message}`; }
        return this.client.send(envelope, message);
      }
    });
    return Promise.all(messagePromises).then(callback.bind(null, null), callback);
  }

  /**
   * Hubot is setting the Slack conversation topic
   * @public
   * @param {Object} envelope - fully documented in SlackClient
   * @param {...string} strings - strings that will be newline separated and set to the conversation topic
   */
  setTopic(envelope, ...strings) {
    // TODO: if the sender is interested in the completion, the last item in `messages` will be a function
    // TODO: this will fail if sending an object as a value in strings
    return this.client.setTopic(envelope.room, strings.join("\n"));
  }

  /**
   * Hubot is sending a reaction
   * NOTE: the super class implementation is just an alias for send, but potentially, we can detect
   * if the envelope has a specific message and send a reactji. the fallback would be to just send the
   * emoji as a message in the channel
   */
  // emote: (envelope, strings...) ->


  /*
   * SlackClient event handlers
   */

  /**
   * Slack client has opened the connection
   * @private
   */
  open() {
    this.robot.logger.info("Connected to Slack RTM");

    // Tell Hubot we're connected so it can load scripts
    return this.emit("connected");
  }

  /**
   * Slack client has authenticated
   *
   * @private
   * @param {SlackRtmStart|SlackRtmConnect} identity - the response from calling the Slack Web API method `rtm.start` or
   * `rtm.connect`
   */
  authenticated(identity) {
    let team;
    ({self: this.self, team} = identity);
    this.self.installed_team_id = team.id;

    // Find out bot_id
    // NOTE: this information can be fetched by using `bots.info` combined with `users.info`. This presents an
    // alternative that decouples Hubot from `rtm.start` and would make it compatible with `rtm.connect`.
    if (identity.users) {
      for (var user of identity.users) {
        if (user.id === this.self.id) {
          this.robot.logger.debug("SlackBot#authenticated() Found self in RTM start data");
          this.self.bot_id = user.profile.bot_id;
          break;
        }
      }
    }

    // Provide name to Hubot so it can be used for matching in `robot.respond()`. This must be a username, despite the
    // deprecation, because the SlackTextMessage#buildText() will format mentions into `@username`, and that is what
    // Hubot will be comparing to the message text.
    this.robot.name = this.self.name;

    return this.robot.logger.info(`Logged in as @${this.robot.name} in workspace ${team.name}`);
  }


  /**
   * Creates a presense subscripton for all users in the brain
   * @private
   */
  presenceSub() {
    // Only subscribe to status changes from human users that are not deleted
    const ids = this.robot.brain.data.users.filter(user => !user.is_bot && !user.deleted).map(user => user.id);
    this.robot.logger.debug(`SlackBot#presenceSub() Subscribing to presence for ${ids.length} users`);
    return this.client.rtm.subscribePresence(ids);
  }

  /**
   * Slack client has closed the connection
   * @private
   */
  close() {
    // NOTE: not confident that @options.autoReconnect works
    if (this.options.autoReconnect) {
      this.robot.logger.info("Disconnected from Slack RTM");
      return this.robot.logger.info("Waiting for reconnect...");
    } else {
      return this.disconnect();
    }
  }

  /**
   * Slack client has closed the connection and will not reconnect
   * @private
   */
  disconnect() {
    this.robot.logger.info("Disconnected from Slack RTM");
    this.robot.logger.info("Exiting...");
    this.client.disconnect();
    // NOTE: Node recommends not to call process.exit() but Hubot itself uses this mechanism for shutting down
    // Can we make sure the brain is flushed to persistence? Do we need to cleanup any state (or timestamp anything)?
    return process.exit(1);
  }

  /**
   * Slack client received an error
   *
   * @private
   * @param {SlackRtmError} error - An error emitted from the [Slack RTM API](https://api.slack.com/rtm)
   */
  error(error) {
    this.robot.logger.error(`Slack RTM error: ${JSON.stringify(error)}`);
    // Assume that scripts can handle slowing themselves down, all other errors are bubbled up through Hubot
    // NOTE: should rate limit errors also bubble up?
    if (error.code !== -1) {
      return this.robot.emit("error", error);
    }
  }

  /**
   * Incoming Slack event handler
   *
   * This method is used to ingest Slack RTM events and prepare them as Hubot Message objects. The messages are passed
   * to the Robot#receive() method, which allows executes receive middleware and eventually triggers the various
   * listeners that are created by scripts.
   *
   * Depending on the exact type of event, additional properties may be present. The following describes the "special"
   * ones that have meaningful handling across all types.
   *
   * @private
   * @param {Object} event
   * @param {string} event.type - this specifies the event type
   * @param {SlackUserInfo} [event.user] - the description of the user creating this event as returned by `users.info`
   * @param {string} [event.channel] - the conversation ID for where this event took place
   * @param {SlackBotInfo} [event.bot] - the description of the bot creating this event as returned by `bots.info`
   */
  eventHandler(event) {
    let msg;
    const {user, channel} = event;
    const event_team_id = event.team;

    // Ignore anything we sent
    if (user?.id === this.self.id) { 
      return;
    }

    if (this.options.installedTeamOnly) {
      // Skip events generated by other workspace users in a shared channel
      if ((event_team_id != null) && (event_team_id !== this.self.installed_team_id)) {
        this.robot.logger.debug(`Skipped an event generated by an other workspace user (team: ${event_team_id}) in shared channel (channel: ${channel})`);
        return;
      }
    }

    // Send to Hubot based on message type
    if (event.type === "message") {

      // Hubot expects all user objects to have a room property that is used in the envelope for the message after it
      // is received
      user.room = channel ?? '';

      switch (event.subtype) {
        case "bot_message":
          this.robot.logger.debug(`Received text message in channel: ${channel}, from: ${user.id} (bot)`);
          return SlackTextMessage.makeSlackTextMessage(user, undefined, undefined, event, channel, this.robot.name, this.robot.alias, this.client, (error, message) => {
            if (error) { return this.robot.logger.error(`Dropping message due to error ${error.message}`); }
            return this.receive(message);
          });

        case "channel_topic": case "group_topic":
          this.robot.logger.debug(`Received topic change message in conversation: ${channel}, new topic: ${event.topic}, set by: ${user.id}`);
          return this.receive(new TopicMessage(user, event.topic, event.ts));

        case "me_message":
          this.robot.logger.debug(`Received /me message in channel: ${channel}, from: ${user.id}`);
          return this.receive(new MeMessage(user, event.text, event.ts));

        case "thread_broadcast": case undefined:
          this.robot.logger.debug(`Received text message in channel: ${channel}, from: ${user.id} (human)`);
          return SlackTextMessage.makeSlackTextMessage(user, undefined, undefined, event, channel, this.robot.name, this.robot.alias, this.client, (error, message) => {
            if (error) { return this.robot.logger.error(`Dropping message due to error ${error.message}`); }
            return this.receive(message);
          });
      }

    } else if (event.type === "member_joined_channel") {
      // this event type always has a channel
      user.room = channel;
      this.robot.logger.debug(`Received enter message for user: ${user.id}, joining: ${channel}`);
      msg = new EnterMessage(user);
      msg.ts = event.ts;
      return this.receive(msg);

    } else if (event.type === "member_left_channel") {
      // this event type always has a channel
      user.room = channel;
      this.robot.logger.debug(`Received leave message for user: ${user.id}, joining: ${channel}`);
      msg = new LeaveMessage(user);
      msg.ts = event.ts;
      return this.receive(msg);

    } else if ((event.type === "reaction_added") || (event.type === "reaction_removed")) {

      // Once again Hubot expects all user objects to have a room property that is used in the envelope for the message
      // after it is received. If the reaction is to a message, then the `event.item.channel` contain a conversation ID.
      // Otherwise reactions can be on files and file comments, which are "global" and aren't contained in a
      // conversation. In that situation we fallback to an empty string.
      user.room = event.item.type === "message" ? event.item.channel : "";

      // Reaction messages may contain an `event.item_user` property containing a fetched SlackUserInfo object. Before
      // the message is received by Hubot, turn that data into a Hubot User object.
      const item_user = (event.item_user != null) ? this.robot.brain.userForId(event.item_user.id, event.item_user) : {};

      this.robot.logger.debug(`Received reaction message from: ${user.id}, reaction: ${event.reaction}, item type: ${event.item.type}`);
      return this.receive(new ReactionMessage(event.type, user, event.reaction, item_user, event.item, event.event_ts));

    } else if (event.type === "presence_change") {
      // Collect all Hubot User objects referenced in this presence change event
      // NOTE: this does not create new Hubot User objects for any users that are not already in the brain. It should
      // not be possible for this to happen since Slack will only send events for users where an explicit subscription
      // was made. In the `presenceSub()` method, subscriptions are only made for users in the brain.
      const users = event.users?.filter(user => user != null) ?? [event.user];
      this.robot.logger.debug(`Received presence update message for users: ${users.map((u) => u.id)} with status: ${event.presence}`);
      return this.receive(new PresenceMessage(users, event.presence));
      
    } else if (event.type === "file_shared") {
    
      // Once again Hubot expects all user objects to have a room property that is used in the envelope for the message
      // after it is received. If the reaction is to a message, then the `event.item.channel` contain a conversation ID.
      // Otherwise reactions can be on files and file comments, which are "global" and aren't contained in a
      // conversation. In that situation we fallback to an empty string.
      user.room = event.channel_id;

      this.robot.logger.debug(`Received file_shared message from: ${event.user_id}, file_id: ${event.file_id}`);
      return this.receive(new FileSharedMessage(user, event.file_id, event.event_ts));
    }
  }


    // NOTE: we may want to wrap all other incoming events as a generic Message
    // else

  /**
   * Callback for fetching all users in workspace. Delegates to `updateUserInBrain()` to write all users to Hubot brain
   *
   * @private
   * @param {Error} [error] - describes an error that occurred while fetching users
   * @param {SlackUsersList} [res] - the response from the Slack Web API method `users.list`
   */
  usersLoaded(err, res) {
    if (err || !res.members.length) {
      this.robot.logger.error("Can't fetch users");
      return;
    }
    return res.members.map((member) => this.client.updateUserInBrain(member));
  }
}

module.exports = SlackBot;
