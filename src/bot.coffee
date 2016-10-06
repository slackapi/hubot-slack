{Adapter, TextMessage, EnterMessage, LeaveMessage, TopicMessage, Message, CatchAllMessage, Robot} = require.main.require 'hubot'

SlackClient = require './client'
ReactionMessage = require './reaction-message'

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

  constructor: (@robot, @options) ->
    @client = new SlackClient(@options, @robot)


  ###
  Slackbot initialization
  ###
  run: ->
    return @robot.logger.error "No service token provided to Hubot" unless @options.token
    return @robot.logger.error "Invalid service token provided, please follow the upgrade instructions" unless (@options.token.substring(0, 5) in ['xoxb-', 'xoxp-'])

    # Setup client event handlers
    @client.on 'open', @open
    @client.on 'close', @close
    @client.on 'error', @error
    @client.on 'message', @message
    @client.on 'reaction_added', @reaction
    @client.on 'reaction_removed', @reaction
    @client.on 'authenticated', @authenticated

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
    for user in identity.users
      if user.id == @self.id
        @self.bot_id = user.profile.bot_id
        break

    # Provide our name to Hubot
    @robot.name = @self.name

    @robot.logger.info "Logged in as #{@robot.name} of #{team.name}"


  ###
  Slack client has closed the connection
  ###
  close: =>
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
  topic: (envelope, strings...) ->
    return if envelope.room[0] is 'D' # ignore DMs

    @client.setTopic envelope.room, strings.join "\n"


  ###
  Message received from Slack
  ###
  message: (message) =>
    {text, user, channel, subtype, topic, bot} = message

    return if user && (user.id == @self.id) #Ignore anything we sent
    return if bot && (bot.id == @self.bot_id) #Ignore anything we sent

    subtype = subtype || 'message'

    # Hubot expects this format for TextMessage Listener
    user = bot if bot
    user = user if user
    user = {} if !user && !bot
    user.room = channel.id


    # Direct messages
    if channel.id[0] is 'D'
      text = "#{@robot.name} #{text}"     # If this is a DM, pretend it was addressed to us
      channel.name ?= channel._modelName  # give the channel a name


    # Send to Hubot based on message type
    switch subtype

      when 'message', 'bot_message'
        @robot.logger.debug "Received message: '#{text}' in channel: #{channel.name}, from: #{user.name}"
        @receive new TextMessage(user, text, message.ts)

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
    user.room = item.channel
    item_user = @client.rtm.dataStore.getUserById(item_user)
    @receive new ReactionMessage(type, user, reaction, item_user, item, event_ts)

module.exports = SlackBot
