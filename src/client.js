const {RtmClient, WebClient} = require("@slack/client");

class SlackClient {
  /**
   * Number of milliseconds which the information returned by `conversations.info` is considered to be valid. The default
   * value is 5 minutes, and it can be customized by setting the `HUBOT_SLACK_CONVERSATION_CACHE_TTL_MS` environment
   * variable. Setting this number higher will reduce the number of requests made to the Web API, which may be helpful if
   * your Hubot is experiencing rate limiting errors. However, setting this number too high will result in stale data
   * being referenced, and your scripts may experience errors related to channel info (like the name) being incorrect
   * after a user changes it in Slack.
   * @private
   */
  static CONVERSATION_CACHE_TTL_MS =
    process.env.HUBOT_SLACK_CONVERSATION_CACHE_TTL_MS
    ? parseInt(process.env.HUBOT_SLACK_CONVERSATION_CACHE_TTL_MS, 10)
    : (5 * 60 * 1000);

  /**
   * @constructor
   * @param {Object} options - Configuration options for this SlackClient instance
   * @param {string} options.token - Slack API token for authentication
   * @param {string} options.apiPageSize - Number used for limit when making paginated requests to Slack Web API list methods
   * @param {Object} [options.rtm={}] - Configuration options for owned RtmClient instance
   * @param {Object} [options.rtmStart={}] - Configuration options for RtmClient#start() method
   * @param {Robot} robot - Hubot robot instance
   */
  constructor(options, robot) {

    // Client initialization
    // NOTE: the recommended initialization options are `{ dataStore: false, useRtmConnect: true }`. However the
    // @rtm.dataStore property is publically accessible, so the recommended settings cannot be used without breaking
    // this object's API. The property is no longer used internally.
    this.robot = robot;
    this.rtm = new RtmClient(options.token, options.rtm);
    this.web = new WebClient(options.token, { maxRequestConcurrency: 1 });
    
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

  /**
   * Open connection to the Slack RTM API
   *
   * @public
   */
  connect() {
    this.robot.logger.debug(`RtmClient#start() with options: ${JSON.stringify(this.rtmStartOpts)}`);
    return this.rtm.start(this.rtmStartOpts);
  }

  /**
   * Set event handler
   *
   * @public
   * @param {SlackClient~eventHandler} callback
   */
  onEvent(callback) {
    if (this.eventHandler !== callback) { 
      return this.eventHandler = callback;
    }
  }

  /**
   * Disconnect from the Slack RTM API
   *
   * @public
   */
  disconnect() {
    this.rtm.disconnect();
    // NOTE: removal of event listeners possibly does not belong in disconnect, because they are not added in connect.
    return this.rtm.removeAllListeners();
  }

  /**
   * Set a channel's topic
   *
   * @public
   * @param {string} conversationId - Slack conversation ID
   * @param {string} topic - new topic
   */
  async setTopic(conversationId, topic) {
    this.robot.logger.debug(`SlackClient#setTopic() with topic ${topic}`);

    // The `conversations.info` method is used to find out if this conversation can have a topic set
    // NOTE: There's a performance cost to making this request, which can be avoided if instead the attempt to set the
    // topic is made regardless of the conversation type. If the conversation type is not compatible, the call would
    // fail, which is exactly the outcome in this implementation.
    try {
      const res = await this.web.conversations.info(conversationId)
      const conversation = res.channel;
      if (!conversation.is_im && !conversation.is_mpim) {
        return await this.web.conversations.setTopic(conversationId, topic);
      } else {
        return this.robot.logger.debug(`Conversation ${conversationId} is a DM or MPDM. These conversation types do not have topics.`);
      }
    } catch (e) {
      this.robot.logger.error(`Error setting topic in conversation ${conversationId}: ${e.message}`);
    }
  }

  /**
   * Send a message to Slack using the Web API.
   *
   * This method is usually called when a Hubot script is sending a message in response to an incoming message. The
   * response object has a `send()` method, which triggers execution of all response middleware, and ultimately calls
   * `send()` on the Adapter. SlackBot, the adapter in this case, delegates that call to this method; once for every item
   * (since its method signature is variadic). The `envelope` is created by the Hubot Response object.
   *
   * This method can also be called when a script directly calls `robot.send()` or `robot.adapter.send()`. That bypasses
   * the execution of the response middleware and directly calls into SlackBot#send(). In this case, the `envelope`
   * parameter is up to the script.
   *
   * The `envelope.room` property is intended to be a conversation ID. Even when that is not the case, this method will
   * makes a reasonable attempt at sending the message. If the property is set to a public or private channel name, it
   * will still work. When there's no `room` in the envelope, this method will fallback to the `id` property. That
   * affordance allows scripts to use Hubot User objects, Slack users (as obtained from the response to `users.info`),
   * and Slack conversations (as obtained from the response to `conversations.info`) as possible envelopes. In the first
   * two cases, envelope.id` will contain a user ID (`Uxxx` or `Wxxx`). Since Hubot runs using a bot token (`xoxb`),
   * passing a user ID as the `channel` argument to `chat.postMessage` (with `as_user=true`) results in a DM from the bot
   * user (if `as_user=false` it would instead result in a DM from slackbot). Leaving `as_user=true` has no effect when
   * the `channel` argument is a conversation ID.
   *
   * NOTE: This method no longer accepts `envelope.room` set to a user name. Using it in this manner will result in a
   * `channel_not_found` error.
   *
   * @public
   * @param {Object} envelope - a Hubot Response envelope
   * @param {Message} [envelope.message] - the Hubot Message that was received and generated the Response which is now
   * being used to send an outgoing message
   * @param {User} [envelope.user] - the Hubot User object representing the user who sent `envelope.message`
   * @param {string} [envelope.room] - a Slack conversation ID for where `envelope.message` was received, usually an
   * alias of `envelope.user.room`
   * @param {string} [envelope.id] - a Slack conversation ID similar to `envelope.room`
   * @param {string|Object} message - the outgoing message to be sent, can be a simple string or a key/value object of
   * optional arguments for the Slack Web API method `chat.postMessage`.
   */
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
      // when the incoming message was inside a thread, send responses as replies to the thread
      // NOTE: consider building a new (backwards-compatible) format for room which includes the thread_ts.
      // e.g. "#{conversationId} #{thread_ts}" - this would allow a portable way to say the message is in a thread
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

  /**
   * Fetch users from Slack API using pagination
   *
   * @public
   * @param {SlackClient~usersCallback} callback
   */
  loadUsers(callback) {
    // some properties of the real results are left out because they are not used
    const combinedResults = { members: [] };
    var pageLoaded = (error, results) => {
      if (error) { return callback(error); }
      // merge results into combined results
      for (var member of results.members) { combinedResults.members.push(member); }

      if(results?.response_metadata?.next_cursor) {
        // fetch next page
        return this.web.users.list({
          limit: this.apiPageSize,
          cursor: results.response_metadata.next_cursor
        }, pageLoaded);
      } else {
        // pagination complete, run callback with results
        return callback(null, combinedResults);
      }
    };
    return this.web.users.list({ limit: this.apiPageSize }, pageLoaded);
  }

  /**
   * Fetch user info from the brain. If not available, call users.info
   * @public
   */
  async fetchUser(userId) {
    // User exists in the brain - retrieve this representation
    if (this.robot.brain.data.users[userId] != null) { 
      return Promise.resolve(this.robot.brain.data.users[userId]);
    }

    // User is not in brain - call users.info
    // The user will be added to the brain in EventHandler
    const r = await this.web.users.info(userId)
    return this.updateUserInBrain(r.user);
  }

  /**
   * Fetch bot user info from the bot -> user map
   * @public
   */
  async fetchBotUser(botId) {
    if (this.botUserIdMap[botId] != null) { 
      return Promise.resolve(this.botUserIdMap[botId]);
    }

    // Bot user is not in mapping - call bots.info
    this.robot.logger.debug(`SlackClient#fetchBotUser() Calling bots.info API for bot_id: ${botId}`);
    const r = await this.web.bots.info({bot: botId})
    return r.bot;
  }

  /**
   * Fetch conversation info from conversation map. If not available, call conversations.info
   * @public
   */
  async fetchConversation(conversationId) {
    // Current date minus time of expiration for conversation info
    const expiration = Date.now() - SlackClient.CONVERSATION_CACHE_TTL_MS;

    // Check whether conversation is held in client's channelData map and whether information is expired
    if (((this.channelData[conversationId] != null ? this.channelData[conversationId].channel : undefined) != null) &&
      (expiration < (this.channelData[conversationId] != null ? this.channelData[conversationId].updated : undefined))) { return Promise.resolve(this.channelData[conversationId].channel); }

    // Delete data from map if it's expired
    if (this.channelData[conversationId] != null) { delete this.channelData[conversationId]; }

    // Return conversations.info promise
    const r = await this.web.conversations.info(conversationId)
    if (r.channel != null) {
      this.channelData[conversationId] = {
        channel: r.channel,
        updated: Date.now()
      };
    }
    return r.channel;
}

  /**
   * Will return a Hubot user object in Brain.
   * User can represent a Slack human user or bot user
   *
   * The returned user from a message or reaction event is guaranteed to contain:
   *
   * id {String}:              Slack user ID
   * slack.is_bot {Boolean}:   Flag indicating whether user is a bot
   * name {String}:            Slack username
   * real_name {String}:       Name of Slack user or bot
   * room {String}:            Slack channel ID for event (will be empty string if no channel in event)
   *
   * This may be called as a handler for `user_change` events or to update a
   * a single user with its latest SlackUserInfo object.
   *
   * @private
   * @param {SlackUserInfo|SlackUserChangeEvent} event_or_user - an object containing information about a Slack user
   * that should be updated in the brain
   */
  updateUserInBrain(event_or_user) {
    // if this method was invoked as a `user_change` event handler, unwrap the user from the event
    let key, value;
    const user = event_or_user.type === 'user_change' ? event_or_user.user : event_or_user;

    // create a full representation of the user in the shape we persist for Hubot brain based on the parameter
    // all top-level properties of the user are meant to be shared across adapters
    const newUser = {
      id: user.id,
      name: user.name,
      real_name: user.real_name,
      slack: {}
    };
    // don't create keys for properties that have no value, because the empty value will become authoritative
    if ((user.profile != null ? user.profile.email : undefined) != null) { newUser.email_address = user.profile.email; }
    // all "non-standard" keys of a user are namespaced inside the slack property, so they don't interfere with other
    // adapters (in case this hubot switched between adapters)
    for (key in user) {
      value = user[key];
      newUser.slack[key] = value;
    }

    // merge any existing representation of this user already stored in the brain into the new representation
    if (user.id in this.robot.brain.data.users) {
      for (key in this.robot.brain.data.users[user.id]) {
        // the merge strategy is to only copy over data for keys that do not exist in the new representation
        // this means the entire `slack` property is treated as one value
        value = this.robot.brain.data.users[user.id][key];
        if (!(key in newUser)) {
          newUser[key] = value;
        }
      }
    }

    // remove the existing representation and write the new representation to the brain
    delete this.robot.brain.data.users[user.id];
    return this.robot.brain.userForId(user.id, newUser);
  }

  /**
   * Processes events to fetch additional data or rearrange the shape of an event before handing off to the eventHandler
   *
   * @private
   * @param {SlackRtmEvent} event - One of any of the events listed in <https://api.slack.com/events> with RTM enabled.
   */
  eventWrapper(event) {
    if (this.eventHandler) {
      // fetch full representations of the user, bot, and potentially the item_user.
      const fetches = [];
      if (event.user) {
        fetches.push(this.fetchUser(event.user));
      } else if (event.bot_id) {
        fetches.push(this.fetchBotUser(event.bot_id));
      }

      if (event.item_user) {
        fetches.push(this.fetchUser(event.item_user));
      }
      // after fetches complete...
      return Promise.all(fetches)
        .then(fetched => {
          if (event.user) {
            event.user = fetched.shift();
          } else if (event.bot_id) {
            let bot = fetched.shift();
            if (this.botUserIdMap[event.bot_id]) {
              event.user = bot;
            // bot_id exists on all messages with subtype bot_message
            // these messages only have a user_id property if sent from a bot user (xoxb token). therefore
            // the above assignment will not happen for all messages from custom integrations or apps without a bot user
            } else if (bot.user_id != null) {
              return this.web.users.info(bot.user_id).then(res => {
                event.user = res.user;
                this.botUserIdMap[event.bot_id] = res.user;
                return event;
              });
            } else {
              // bot doesn't have an associated user id
              this.botUserIdMap[event.bot_id] = false;
              event.user = {};
            }
          } else {
            event.user = {};
          }

          if (event.item_user) {
            event.item_user = fetched.shift();
          }
          return event;
      }).then(fetchedEvent => {
          // hand the event off to the eventHandler
          try {
            this.eventHandler(fetchedEvent);
          }
          catch (error) {
            this.robot.logger.error(`An error occurred while processing an RTM event: ${error.message}.`);
          }
        }).catch(error => {
          return this.robot.logger.error(`Incoming RTM message dropped due to error fetching info for a property: ${error.message}.`);
      });
    }
  }
}

/**
 * A handler for all incoming Slack events that are meaningful for the Adapter
 *
 * @callback SlackClient~eventHandler
 * @param {Object} event
 * @param {SlackUserInfo} event.user
 * @param {string} event.channel
 */

/**
 * Callback that recieves a list of users
 *
 * @callback SlackClient~usersCallback
 * @param {Error|null} error - an error if one occurred
 * @param {Object} results
 * @param {Array<SlackUserInfo>} results.members
 */

if (SlackClient.CONVERSATION_CACHE_TTL_MS === NaN) {
  throw new Error('HUBOT_SLACK_CONVERSATION_CACHE_TTL_MS must be a number. It could not be parsed.');
}

module.exports = SlackClient;
