{Adapter, TextMessage, EnterMessage, LeaveMessage, TopicMessage, Message, CatchAllMessage, Robot} = require.main.require 'hubot'

SlackClient = require './client'
ReactionMessage = require './reaction-message'
PresenceMessage = require './presence-message'
SlackTextMessage = require './slack-message'

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

# Public: Adds a Listener for PresenceMessages with the provided matcher,
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
Robot::presenceChange = (matcher, options, callback) ->
  matchPresence = (msg) -> msg instanceof PresenceMessage

  if arguments.length == 1
    return @listen matchPresence, matcher

  else if matcher instanceof Function
    matchPresence = (msg) -> msg instanceof PresenceMessage && matcher(msg)

  else
    callback = options
    options = matcher

  @listen matchPresence, options, callback

class SlackBot extends Adapter

  constructor: (@robot, @options) ->
    @client = new SlackClient(@options, @robot)

  ###
  Slackbot loads full user list on the first brain load
  QUESTION: why do brain adapters trigger a brain 'loaded' event each time a key
  is set?
  ###
  setIsLoaded: (@isLoaded) ->

  ###
  Slackbot initialization
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
    @client.rtm.on 'presence_change', @presenceChange

    @client.loadUsers @loadUsers
    @client.onMessage @message

    @robot.brain.on 'loaded', () =>
      if not @isLoaded
        @client.loadUsers @loadUsers
        @setIsLoaded(true)
        @presence_sub()

    # Start logging in
    @client.connect()


  ###
  Slack client has opened the connection
  ###
  open: =>
    @robot.logger.info 'Slack client now connected'

    # Tell Hubot we're connected so it can load scripts
    @emit "connected"


  ###
  Slack client has authenticated
  ###
  authenticated: (identity) =>
    {@self, team} = identity

    # Find out bot_id
    if identity.users
      for user in identity.users
        if user.id == @self.id
          @self.bot_id = user.profile.bot_id
          break

    # Provide our name to Hubot
    @robot.name = @self.name

    @robot.logger.info "Logged in as #{@robot.name} of #{team.name}"

    
  ###
  Subscribes for presence change updates for all active non bot users
  This is necessary since January 2018 see https://api.slack.com/changelog/2018-01-presence-present-and-future
  ###
  presence_sub: () =>
    usersArray = Object.values @robot.brain.data.users
    # Only status changes from active users are relevant
    members = usersArray.filter (user) => not user.is_bot and not user.deleted
    ids = members.map (user) => user.id

    @client.rtm.subscribePresence ids

  ###
  Slack client has closed the connection
  ###
  close: =>
    # NOTE: not confident that @options.autoReconnect has intended effect as currently implemented
    if @options.autoReconnect
      @robot.logger.info 'Slack client closed, waiting for reconnect'
    else
      @robot.logger.info 'Slack client connection was closed, exiting hubot process'
      @client.disconnect()
      process.exit 1


  ###
  Slack client received an error
  ###
  error: (error) =>
    if error.code is -1
      return @robot.logger.warning "Received rate limiting error #{JSON.stringify error}"

    @robot.emit 'error', error


  ###
  Hubot is sending a message to Slack
  ###
  send: (envelope, messages...) ->
    sent_messages = []
    for message in messages
      if message isnt ''
        sent_messages.push @client.send(envelope, message)
    return sent_messages


  ###
  Hubot is replying to a Slack message
  ###
  reply: (envelope, messages...) ->
    sent_messages = []
    for message in messages
      if message isnt ''
        message = "<@#{envelope.user.id}>: #{message}" unless envelope.room[0] is 'D'
        @robot.logger.debug "Sending to #{envelope.room}: #{message}"
        sent_messages.push @client.send(envelope, message)
    return sent_messages


  ###
  Hubot is setting the Slack channel topic
  ###
  setTopic: (envelope, strings...) ->
    return if envelope.room[0] is 'D' # ignore DMs

    @client.setTopic envelope.room, strings.join "\n"


  ###
  Message received from Slack
  ###
  message: (message) =>
    {text, rawText, returnRawText, user, channel, subtype, topic, bot} = message

    return if user && (user.id == @self.id) # Ignore anything we sent, or anything from an unknown user
    return if bot && (bot.id == @self.bot_id) # Ignore anything we sent, or anything from an unknown bot

    subtype = subtype || 'message'

    # Hubot expects this format for TextMessage Listener
    user = bot if !user
    user = {} if !user
    user.room = channel.id


    # Direct messages
    if channel.id[0] is 'D'
      text = "#{@robot.name} #{text}"     # If this is a DM, pretend it was addressed to us
      channel.name ?= channel._modelName  # give the channel a name


    # Send to Hubot based on message type
    switch subtype

      when 'message', 'bot_message'
        @robot.logger.debug "Received message: '#{text}' in channel: #{channel.name}, from: #{user.name}"
        if returnRawText
          textMessage = new SlackTextMessage(user, text, rawText, message)
        else
          textMessage = new TextMessage(user, text, message.ts)
        textMessage.thread_ts = message.thread_ts
        @receive textMessage

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
        @robot.logger.debug "Received message: '#{text}' in channel: #{channel.name}, subtype: #{subtype}"
        message.user = user
        @receive new CatchAllMessage(message)

  ###
  Reaction added/removed event received from Slack
  ###
  reaction: (message) =>
    {type, user, reaction, item_user, item, event_ts} = message
    return if (user == @self.id) || (user == @self.bot_id) #Ignore anything we sent

    user = @client.rtm.dataStore.getUserById(user)
    item_user = @client.rtm.dataStore.getUserById(item_user)
    return unless user && item_user

    user.room = item.channel
    @receive new ReactionMessage(type, user, reaction, item_user, item, event_ts)

  ###
  presence changed event received from Slack
  ###
  presenceChange: (message) =>
    # prepare for the removal of the deprecated single presence change updates
    userIds = if message.user then [message.user] else message.users

    users = []
    for id in userIds
      user = @client.rtm.dataStore.getUserById(id)
      if user then users.push user

    return unless users
    @receive new PresenceMessage(users, message.presence)

  # Callback for SlackClient.loadUsers()
  loadUsers: (err, res) =>
    if err || !res.members.length
      @robot.logger.error "Can't fetch users"
      return

    @userChange member for member in res.members

  # when invoked as an event handler, this method takes an event. but when invoked from loadUsers,
  # this method takes a user
  userChange: (event_or_user) =>
    return unless event_or_user
    user = if event_or_user.type == 'user_change' then event_or_user.user else event_or_user
    newUser =
      id: user.id
      name: user.name
      display_name: user.profile.display_name
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
