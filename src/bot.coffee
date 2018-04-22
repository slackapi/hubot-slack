{Adapter, TextMessage, EnterMessage, LeaveMessage, TopicMessage, CatchAllMessage} = require.main.require "hubot"
{SlackTextMessage, ReactionMessage, PresenceMessage}                              = require "./message"
SlackClient                                                                       = require "./client"
pkg                                                                               = require "../package"

class SlackBot extends Adapter

  ###*
  # Slackbot is an adapter for connecting Hubot to Slack
  # @constructor
  # @param {Robot} robot - the Hubot robot
  # @param {Object} options - configuration options for the adapter
  # @param {string} options.token - authentication token for Slack APIs
  # @param {Object} options.rtm - RTM configuration options for SlackClient
  # @param {Object} options.rtmStart - options for `rtm.start` Web API method
  ###
  constructor: (@robot, @options) ->
    super
    @robot.logger.info "hubot-slack adapter v#{pkg.version}"
    @client = new SlackClient @options, @robot


  ###
  # Hubot Adapter methods
  ###

  ###*
  # Slackbot initialization
  # @public
  ###
  run: ->
    # Token validation
    return @robot.logger.error "No service token provided to Hubot" unless @options.token
    return @robot.logger.error "Invalid service token provided, please follow the upgrade instructions" unless (@options.token.substring(0, 5) in ["xoxb-", "xoxp-"])

    # SlackClient event handlers
    @client.rtm.on "open", @open
    @client.rtm.on "close", @close
    @client.rtm.on "error", @error
    @client.rtm.on "authenticated", @authenticated
    @client.rtm.on "user_change", @updateUserInBrain
    @client.onEvent @eventHandler

    # Synchronize workspace users to brain
    @client.loadUsers @usersLoaded

    # Brain will emit 'loaded' the first time it connects to its storage and then again each time a key is set
    @robot.brain.on "loaded", () =>
      if not @brainIsLoaded
        @brainIsLoaded = true
        # The following code should only run after the first time the brain connects to its storage

        # There's a race condition where the connection can happen after the above `@client.loadUsers` call finishes,
        # in which case the calls to save users in `@usersLoaded` would not persist. It is still necessary to call the
        # method there in the case Hubot is running without brain storage.
        # NOTE: is this actually true? won't the brain have the users in memory and persist to storage as soon as the
        # connection is complete?
        # NOTE: this seems wasteful. when there is brain storage, it will end up loading all the users twice.
        @client.loadUsers @usersLoaded

        # NOTE: will this only subscribe a partial user list because loadUsers has not yet completed? it will at least
        # subscribe to the users that were stored in the brain from the last run.
        @presenceSub()

    # Start logging in
    @client.connect()

  ###*
  # Hubot is sending a message to Slack
  #
  # @public
  # @param {Object} envelope - fully documented in SlackClient
  # @param {...(string|Object)} messages - fully documented in SlackClient
  ###
  send: (envelope, messages...) ->
    # TODO: if the sender is interested in the completion, the last item in `messages` will be a function
    for message in messages
      # NOTE: perhaps do envelope manipulation here instead of in the client (separation of concerns)
      @client.send(envelope, message) unless message is ""

  ###*
  # Hubot is replying to a Slack message
  # @public
  # @param {Object} envelope - fully documented in SlackClient
  # @param {...(string|Object)} messages - fully documented in SlackClient
  ###
  reply: (envelope, messages...) ->
    # TODO: if the sender is interested in the completion, the last item in `messages` will be a function
    for message in messages
      if message isnt ""
        # TODO: channel prefix matching should be removed
        message = "<@#{envelope.user.id}>: #{message}" unless envelope.room[0] is "D"
        @client.send envelope, message

  ###*
  # Hubot is setting the Slack conversation topic
  # @public
  # @param {Object} envelope - fully documented in SlackClient
  # @param {...string} strings - strings that will be newline separated and set to the conversation topic
  ###
  setTopic: (envelope, strings...) ->
    # TODO: if the sender is interested in the completion, the last item in `messages` will be a function
    # TODO: this will fail if sending an object as a value in strings
    @client.setTopic envelope.room, strings.join("\n")

  ###*
  # Hubot is sending a reaction
  # NOTE: the super class implementation is just an alias for send, but potentially, we can detect
  # if the envelope has a specific message and send a reactji. the fallback would be to just send the
  # emoji as a message in the channel
  ###
  # emote: (envelope, strings...) ->


  ###
  # SlackClient event handlers
  ###

  ###*
  # Slack client has opened the connection
  # @private
  ###
  open: =>
    @robot.logger.info "Connected to Slack RTM"

    # Tell Hubot we're connected so it can load scripts
    @emit "connected"

  ###*
  # Slack client has authenticated
  #
  # @private
  # @param {SlackRtmStart|SlackRtmConnect} identity - the response from calling the Slack Web API method `rtm.start` or
  # `rtm.connect`
  ###
  authenticated: (identity) =>
    {@self, team} = identity

    # Find out bot_id
    # NOTE: this information can be fetched by using `bots.info` combined with `users.info`. This presents an
    # alternative that decouples Hubot from `rtm.start` and would make it compatible with `rtm.connect`.
    if identity.users
      for user in identity.users
        if user.id == @self.id
          @self.bot_id = user.profile.bot_id
          @self.display_name = user.profile.display_name
          break

    # Provide name to Hubot so it can be used for matching in `robot.respond()`. This must be a username, despite the
    # deprecation, because the SlackTextMessage#buildText() will format mentions into `@username`, and that is what
    # Hubot will be comparing to the message text.
    @robot.name = @self.name

    @robot.logger.info "Logged in as @#{@self.display_name} in workspace #{team.name}"


  ###*
  # Creates a presense subscripton for all users in the brain
  # @private
  ###
  presenceSub: =>
    # Only subscribe to status changes from human users that are not deleted
    ids = for own id, user of @robot.brain.data.users when (not user.is_bot and not user.deleted)
      id
    @client.rtm.subscribePresence ids

  ###*
  # Slack client has closed the connection
  # @private
  ###
  close: =>
    @robot.logger.info "Disconnected from Slack RTM"
    # NOTE: not confident that @options.autoReconnect works
    if @options.autoReconnect
      @robot.logger.info "Waiting for reconnect..."
    else
      @robot.logger.info "Exiting..."
      @client.disconnect()
      # NOTE: Node recommends not to call process.exit() but Hubot itself uses this mechanism for shutting down
      # Can we make sure the brain is flushed to persistence? Do we need to cleanup any state (or timestamp anything)?
      process.exit 1

  ###*
  # Slack client received an error
  #
  # @private
  # @param {SlackRtmError} error - An error emitted from the [Slack RTM API](https://api.slack.com/rtm)
  ###
  error: (error) =>
    @robot.logger.error "Slack RTM error: #{JSON.stringify error}"
    # Assume that scripts can handle slowing themselves down, all other errors are bubbled up through Hubot
    # NOTE: should rate limit errors also bubble up?
    if error.code isnt -1
      @robot.emit "error", error

  ###*
  # Incoming Slack event handler
  #
  # This method is used to ingest Slack RTM events and prepare them as Hubot Message objects. The messages are passed
  # to the Robot#receive() method, which allows executes receive middleware and eventually triggers the various
  # listeners that are created by scripts.
  #
  # Depending on the exact type of event, additional properties may be present. The following describes the "special"
  # ones that have meaningful handling across all types.
  #
  # @private
  # @param {Object} event
  # @param {string} event.type - this specifies the event type
  # @param {SlackUserInfo} [event.user] - the description of the user creating this event as returned by `users.info`
  # @param {SlackConversationInfo} [event.channel] - the description of the conversation where the event happened as
  # returned by `conversations.info`
  # @param {SlackBotInfo} [event.bot] - the description of the bot creating this event as returned by `bots.info`
  ###
  eventHandler: (event) =>
    {user, channel} = event

    # Ignore anything we sent
    return if user?.id is @self.id

    ###*
    # Hubot user object in Brain.
    # User can represent a Slack human user or bot user
    #
    # The returned user from a message or reaction event is guaranteed to contain:
    #
    # id {String}:              Slack user ID
    # slack.is_bot {Boolean}:   Flag indicating whether user is a bot
    # name {String}:            Slack username
    # real_name {String}:       Name of Slack user or bot
    # room {String}:            Slack channel ID for event (will be empty string if no channel in event)
    ###
    # NOTE: should this be using `updateUserInBrain()`?
    user = if user? then @robot.brain.userForId user.id, user else {}

    # Send to Hubot based on message type
    if event.type is "message"

      # Hubot expects all user objects to have a room property that is used in the envelope for the message after it
      # is received
      user.room = if channel? then channel.id else ""

      switch event.subtype
        when "bot_message"
          @robot.logger.debug "Received text message in channel: #{channel.id}, from: #{user.id} (bot)"
          SlackTextMessage.makeSlackTextMessage(user, undefined, undefined, event, channel, @robot.name, @robot.alias, @client, (message) =>
            @receive message
          )

        # NOTE: channel_join should be replaced with a member_joined_channel event
        when "channel_join", "group_join"
          @robot.logger.debug "Received enter message for user: #{user.id}, joining: #{channel.id}"
          @receive new EnterMessage user

        # NOTE: channel_leave should be replaced with a member_left_channel event
        when "channel_leave", "group_leave"
          @robot.logger.debug "Received leave message for user: #{user.id}, leaving: #{channel.id}"
          @receive new LeaveMessage user

        when "channel_topic", "group_topic"
          @robot.logger.debug "Received topic change message in conversation: #{channel.id}, new topic: #{event.topic}, set by: #{user.id}"
          @receive new TopicMessage user, event.topic, event.ts

        when undefined
          @robot.logger.debug "Received text message in channel: #{channel.id}, from: #{user.id} (human)"
          SlackTextMessage.makeSlackTextMessage(user, undefined, undefined, event, channel, @robot.name, @robot.alias, @client, (message) =>
            @receive message
          )

    else if event.type is "reaction_added" or event.type is "reaction_removed"

      # Once again Hubot expects all user objects to have a room property that is used in the envelope for the message
      # after it is received. If the reaction is to a message, then the `event.item.channel` contain a conversation ID.
      # Otherwise reactions can be on files and file comments, which are "global" and aren't contained in a
      # conversation. In that situation we fallback to an empty string.
      user.room = if event.item.type is "message" then event.item.channel else ""

      # Reaction messages may contain an `event.item_user` property containing a fetched SlackUserInfo object. Before
      # the message is received by Hubot, turn that data into a Hubot User object.
      item_user = if event.item_user? then @robot.brain.userForId event.item_user.id, event.item_user else {}

      @robot.logger.debug "Received reaction message from: #{user.id}, reaction: #{event.reaction}, item type: #{event.item.type}"
      @receive new ReactionMessage(event.type, user, event.reaction, item_user, event.item, event.event_ts)

    else if event.type is "presence_change"
      # Collect all Hubot User objects referenced in this presence change event
      # NOTE: this does not create new Hubot User objects for any users that are not already in the brain. It should
      # not be possible for this to happen since Slack will only send events for users where an explicit subscription
      # was made. In the `presenceSub()` method, subscriptions are only made for users in the brain.
      users = for user_id in (event.users or [event.user.id]) when @robot.brain.data.users[user_id]?
        @robot.brain.data.users[user_id]

      @robot.logger.debug "Received presence update message for users: #{u.id for u in users} with status: #{event.presence}"
      @receive new PresenceMessage(users, event.presence)

    # NOTE: we may want to wrap all other incoming events as a generic Message
    # else

  ###*
  # Callback for fetching all users in workspace. Delegates to `updateUserInBrain()` to write all users to Hubot brain
  #
  # @private
  # @param {Error} [error] - describes an error that occurred while fetching users
  # @param {SlackUsersList} [res] - the response from the Slack Web API method `users.list`
  ###
  usersLoaded: (err, res) =>
    if err || !res.members.length
      @robot.logger.error "Can't fetch users"
      return
    @updateUserInBrain member for member in res.members

  ###*
  # Update user record in the Hubot Brain. This may be called as a handler for `user_change` events or to update a
  # a single user with its latest SlackUserInfo object.
  #
  # @private
  # @param {SlackUserInfo|SlackUserChangeEvent} event_or_user - an object containing information about a Slack user
  # that should be updated in the brain
  ###
  updateUserInBrain: (event_or_user) =>
    # NOTE: why is this line here and why would this method be called without any parameter?
    return unless event_or_user

    # if this method was invoked as a `user_change` event handler, unwrap the user from the event
    user = if event_or_user.type == 'user_change' then event_or_user.user else event_or_user

    # create a full representation of the user in the shape we persist for Hubot brain based on the parameter
    # all top-level properties of the user are meant to be shared across adapters
    newUser =
      id: user.id
      name: user.name
      real_name: user.real_name
      slack: {}
    # don't create keys for properties that have no value, because the empty value will become authoritative
    newUser.email_address = user.profile.email if user.profile?.email?
    # all "non-standard" keys of a user are namespaced inside the slack property, so they don't interfere with other
    # adapters (in case this hubot switched between adapters)
    for key, value of user
      newUser.slack[key] = value

    # merge any existing representation of this user already stored in the brain into the new representation
    if user.id of @robot.brain.data.users
      for key, value of @robot.brain.data.users[user.id]
        # the merge strategy is to only copy over data for keys that do not exist in the new representation
        # this means the entire `slack` property is treated as one value
        unless key of newUser
          newUser[key] = value

    # remove the existing representation and write the new representation to the brain
    delete @robot.brain.data.users[user.id]
    @robot.brain.userForId user.id, newUser


module.exports = SlackBot
