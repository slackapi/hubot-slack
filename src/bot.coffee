{ Adapter, TextMessage, EnterMessage, LeaveMessage, TopicMessage, CatchAllMessage } = require.main.require 'hubot'
{ SlackTextMessage, ReactionMessage } = require './message'
SlackClient = require './client'

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
    @client = new SlackClient(@options, @robot)


  ###
  # Hubot Adapter methods
  ###

  ###*
  # Slackbot initialization
  # @public
  ###
  run: ->
    return @robot.logger.error "No service token provided to Hubot" unless @options.token
    return @robot.logger.error "Invalid service token provided, please follow the upgrade instructions" unless (@options.token.substring(0, 5) in ['xoxb-', 'xoxp-'])

    # Setup client event handlers
    @client.rtm.on 'open', @open
    @client.rtm.on 'close', @close
    @client.rtm.on 'error', @error
    @client.rtm.on 'authenticated', @authenticated
    @client.rtm.on 'user_change', @updateUserInBrain

    @client.onEvent @eventHandler

    # TODO: set this to false as soon as RTM connection closes (even if reconnect will happen later)
    # TODO: check this value when connection finishes (even if its a reconnection)
    # TODO: build a map of enterprise users and local users
    @needsUserListSync = true
    @client.loadUsers @usersLoaded
    @robot.brain.on 'loaded', () =>
      # Hubot Brain emits 'loaded' event each time a key is set, but we only want to synchonize the users list on
      # the first load after a connection completes
      if not @isLoaded
        @client.loadUsers @usersLoaded
        @isLoaded = true

    # Start logging in
    @client.connect()

  ###*
  # Hubot is sending a message to Slack
  # @public
  ###
  send: (envelope, messages...) ->
    for message in messages
      # NOTE: perhaps do envelope manipulation here instead of in the client (separation of concerns)
      @client.send(envelope, message) unless message is ''

  ###*
  # Hubot is replying to a Slack message
  # @public
  ###
  reply: (envelope, messages...) ->
    for message in messages
      if message isnt ''
        # TODO: channel prefix matching should be removed
        message = "<@#{envelope.user.id}>: #{message}" unless envelope.room[0] is 'D'
        @client.send(envelope, message)

  ###*
  # Hubot is setting the Slack channel topic
  # @public
  ###
  setTopic: (envelope, strings...) ->
    @client.setTopic envelope.room, strings.join "\n"

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
    @robot.logger.info 'Slack client now connected'

    # Tell Hubot we're connected so it can load scripts
    @emit "connected"

  ###*
  # Slack client has authenticated
  # @private
  ###
  authenticated: (identity) =>
    {@self, team} = identity

    # Find out bot_id
    # NOTE: this could be done with a call to `bots.info`, and that would allow for transition to `rtm.connect`
    for user in identity.users
      if user.id == @self.id
        @self.bot_id = user.profile.bot_id
        break

    # Provide our name to Hubot
    # NOTE: this value is used to match incoming TextMessages that are directed to the robot. investigate
    # if this is effective with mentions formatted as "<@U12345|name>", "<@U12345>", "<@W12345|name>", "<@W12345>".
    # the matching criteria:
    #   1. prepend any special characters (from "-[]{}()*+?.,\^$|# ") in name and alias with a "\"
    #   2. optionally start with "@", followed by alias or name, optionally followed by any from ":,", optionally followed by whitespace
    @robot.name = @self.name

    @robot.logger.info "Logged in as #{@robot.name} of #{team.name}"

  ###*
  # Slack client has closed the connection
  # @private
  ###
  close: =>
    # NOTE: not confident that @options.autoReconnect has intended effect as currently implemented
    if @options.autoReconnect
      @robot.logger.info 'Slack client closed, waiting for reconnect'
    else
      @robot.logger.info 'Slack client connection was closed, exiting hubot process'
      @client.disconnect()
      process.exit 1

  ###*
  # Slack client received an error
  # @private
  ###
  error: (error) =>
    if error.code is -1
      return @robot.logger.warning "Received rate limiting error #{JSON.stringify error}"
    @robot.emit 'error', error

  ###*
  # Event received from Slack
  # @private
  ###
  eventHandler: (event) =>
    {user, channel, bot} = event

    # Ignore anything we sent
    # NOTE: coupled to getting `rtm.start` data
    return if (user && (user.id is @self.id || user.id is @self.bot_id)) || (bot && (bot.id is @self.bot_id))

    

    # Send to Hubot based on message type
    if event.type is 'message'
      
      # Hubot expects this format for TextMessage Listener
      # NOTE: use robot.brain.userForId(id, options) to initialize the user object
      # think about whether this is true for bots and if we want to be storing bots in the same brain namespace as users
      bot.room = channel.id if bot
      user.room = channel.id if user

      # Hubot expects this format for TextMessage Listener
      user = bot if !user
      user = {} if !user
      user.room = channel.id

      switch event.subtype
        when 'bot_message'
          @robot.logger.debug "Received message in channel: #{channel.name || channel.id}, from: #{user.name}"

          # prefer user over bot.
          # if both are set in the slack event, it represents an app or integration sending a message on behalf of a
          # user, so the user is the more appropriate value.
          SlackTextMessage.makeSlackTextMessage(user, undefined, undefined, event, channel, @robot.name, @client, (message) =>
            @receive message
          )
        # NOTE: channel_join should be replaced with a member_joined_channel event
        when 'channel_join', 'group_join'
          @robot.logger.debug "#{user.name} has joined #{channel.name || channel.id}"
          @receive new EnterMessage user
        # NOTE: channel_leave should be replaced with a member_left_channel event
        when 'channel_leave', 'group_leave'
          @robot.logger.debug "#{user.name} has left #{channel.name || channel.id}"
          @receive new LeaveMessage user
        when 'channel_topic', 'group_topic'
          @robot.logger.debug "#{user.name} set the topic in #{channel.name || channel.id} to #{event.topic}"
          @receive new TopicMessage user, event.topic, event.ts
        when undefined
          @robot.logger.debug "Received message in channel: #{channel.name || channel.id}, from: #{user.name}"
          
          SlackTextMessage.makeSlackTextMessage(user, undefined, undefined, event, channel, @robot.name, @client, (message) =>
            @receive message
          )
        # NOTE: if we want to expose all remaining subtypes not covered above as a generic message implement an else
        # else

    else if event.type is 'reaction_added' or event.type is 'reaction_removed'      
      # If the reaction is to a message, then the item.channel property will contain a conversation ID
      # Otherwise reactions can be on files and file comments, which are "global" and aren't contained in a conversation
      user.room = event.item?.channel # when the item is not a message this will be undefined


      # prefer user over bot.
      # if both are set in the slack event, it represents an app or integration reacting on behalf of a user, so the
      # user is the more appropriate value.
      @receive new ReactionMessage(event.type, user, event.reaction, event.item_user, event.item, event.event_ts)

  ###*
  # @private
  ###
  usersLoaded: (err, res) =>
    if err || !res.ok
      @robot.logger.error "Can't fetch users"
      return

    @updateUserInBrain member for member in res.members

  ###*
  # Update user record in the Hubot Brain
  # @private
  ###
  updateUserInBrain: (event_or_user) =>
    return unless event_or_user
    # when invoked as an event handler, this method takes an event.
    # but when invoked from usersLoaded, this method takes a user.
    user = if event_or_user.type == 'user_change' then event_or_user.user else event_or_user
    newUser =
      id: user.id
      name: user.name
      real_name: user.real_name
      slack: {}
    newUser.email_address = user.profile.email if user.profile and user.profile.email
    for key, value of user
      # don't store the SlackClient, because it'd cause a circular reference
      # (it contains users and channels), and because it has sensitive information like the token
      continue if value instanceof SlackClient
      newUser.slack[key] = value

    if user.id of @robot.brain.data.users
      for key, value of @robot.brain.data.users[user.id]
        unless key of newUser
          newUser[key] = value
    delete @robot.brain.data.users[user.id]
    @robot.brain.userForId user.id, newUser


module.exports = SlackBot

# Open question:
# What is a `room` for this adapter? There needs to be a contract about what is and is not a valid `room`?
# The most basic contract would be a room is a string that is a Slack conversationId.
# There's also precidence (from documentation) that the value in `user.name` should be used as a room. If we could
# detect a `user.name`, then maybe its possible to find the user ID and then open a DM to retreive a conversationId. We
# should only do this if its supported already, because Slack's latest guidance is to not use display names for any
# programmatic purpose.

# NOTE: should 'room' describe a thread_ts too for messages that are a part of a thread, so that a response.send()
# (or other variant) can continue interacting in the thread? is there a way to respond to the "parent" room?
