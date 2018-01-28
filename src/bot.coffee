{ Adapter, TextMessage, EnterMessage, LeaveMessage, TopicMessage, CatchAllMessage, Robot } = require.main.require 'hubot'
{ SlackTextMessage, ReactionMessage } = require './message';
SlackClient = require './client'

# Public: Adds a Listener for ReactionMessages with the provided matcher,
# options, and callback
#
# matcher  - A Function that determines whether to call the callback.
#            Expected to return a truthy value if the callback should be
#            executed (optional).
# options  - An Object of additional parameters keyed on extension name
#            (optional).
# callback - A Function that is called with a Response object if the
#            matcher function returns true.
#
# Returns nothing.
Robot::react = (matcher, options, callback) ->
  matchReaction = (msg) -> msg instanceof ReactionMessage

  if arguments.length == 1
    return @listen matchReaction, matcher

  else if matcher instanceof Function
    matchReaction = (msg) -> msg instanceof ReactionMessage && matcher(msg)

  else
    callback = options
    options = matcher

  @listen matchReaction, options, callback

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
    @client.rtm.on 'reaction_added', @reaction
    @client.rtm.on 'reaction_removed', @reaction
    @client.rtm.on 'authenticated', @authenticated
    @client.rtm.on 'user_change', @userChange
    @client.onMessage @message

    # TODO: set this to false as soon as RTM connection closes (even if reconnect will happen later)
    # TODO: check this value when connection finishes (even if its a reconnection)
    # TODO: build a map of enterprise users and local users
    @needsUserListSync = true
    @client.loadUsers @usersLoaded
    @robot.brain.on 'loaded', () =>
      # Hubot Brain emits 'loaded' event each time a key is set, but we only want to synchonize the users list on
      # the first load after a connection completes
      if not @isLoaded
        @client.loadUsers @loadUsers
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
  topic: (envelope, strings...) ->
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
  # Message received from Slack
  # @private
  ###
  message: (message) =>
    {user, channel, subtype, topic, bot} = message

    return if user && (user.id == @self.id) # Ignore anything we sent, or anything from an unknown user
    return if bot && (bot.id == @self.bot_id) # Ignore anything we sent, or anything from an unknown bot

    # Hubot expects this format for TextMessage Listener
    user = bot if !user
    user = {} if !user
    user.room = channel.id

    # Make sure there's a readable channel name to log
    channel.name ?= channel.id

    # Send to Hubot based on message type
    subtype ?= 'message'
    switch subtype

      when 'message', 'bot_message'
        @robot.logger.debug "Received message in channel: #{channel.name}, from: #{user.name}"
        @receive new SlackTextMessage(user, undefined, undefined, message, channel, @robot.name)

      when 'channel_join', 'group_join'
        @robot.logger.debug "#{user.name} has joined #{channel.name}"
        @receive new EnterMessage user

      when 'channel_leave', 'group_leave'
        @robot.logger.debug "#{user.name} has left #{channel.name}"
        @receive new LeaveMessage user

      when 'channel_topic', 'group_topic'
        @robot.logger.debug "#{user.name} set the topic in #{channel.name} to #{topic}"
        @receive new TopicMessage user, message.topic, message.ts

      else
        @robot.logger.debug "Received message in channel: #{channel.name}, subtype: #{subtype}"
        message.user = user
        @receive new CatchAllMessage(message)

  ###*
  # Reaction added/removed event received from Slack
  # @private
  ###
  reaction: (message) =>
    {type, user, reaction, item_user, item, event_ts} = message
    return if (user == @self.id) || (user == @self.bot_id) #Ignore anything we sent

    user = @client.rtm.dataStore.getUserById(user)
    item_user = @client.rtm.dataStore.getUserById(item_user)
    return unless user && item_user

    user.room = item.channel
    @receive new ReactionMessage(type, user, reaction, item_user, item, event_ts)

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
    # but when invoked from loadUsers, this method takes a user.
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
