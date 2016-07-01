{Adapter, TextMessage, EnterMessage, LeaveMessage, TopicMessage, Message} = require.main.require 'hubot'

SlackClient = require './client'

class SlackBot extends Adapter

  constructor: (@robot, @options) ->
    @client = new SlackClient(@options)


  ###
  Slackbot initialization
  ###
  run: ->
    return @robot.logger.error "No services token provided to Hubot" unless @options.token
    return @robot.logger.error "v2 services token provided, please follow the upgrade instructions" unless (@options.token.substring(0, 5) in ['xoxb-', 'xoxp-'])

    # Setup client event handlers
    @client.on 'message', @message
    @client.on 'open', @clientOpen
    @client.on 'close', @clientClose
    @client.on 'close', @clientError
    @client.on 'authenticated', @authenticated

    # Start logging in
    @client.connect()


  ###
  Slack client has opened the connection
  ###
  clientOpen: =>
    @robot.logger.info 'Slack client now connected'

    # Tell Hubot we're connected so it can load scripts
    @emit "connected"


  ###
  Slack client has authenticated
  ###
  authenticated: (identity) =>
    {@self, team} = identity

    # Provide our name to Hubot
    @robot.name = @self.name

    @robot.logger.info "Logged in as #{@robot.name} of #{team.name}"


  ###
  Slack client has closed the connection
  ###
  clientClose: =>
    if @options.autoReconnect
      @robot.logger.info 'Slack client closed, waiting for reconnect'
    else
      @robot.logger.info 'Slack client connection was closed, exiting hubot process'
      @client.disconnect()
      process.exit 1


  ###
  Slack client received an error
  ###
  clientError: (error) =>
    if error.code is -1
      return @robot.logger.warning "Received rate limiting error #{JSON.stringify error}"

    @robot.emit 'error', error


  ###
  Hubot is sending a message to Slack
  ###
  send: (envelope, messages...) ->
    for message in messages
      @robot.logger.debug "Sending to #{envelope.room}: #{message}"
      @client.send(envelope, message)


  ###
  Hubot is replying to a Slack message
  ###
  reply: (envelope, messages...) ->
    @robot.logger.debug "Sending reply"

    for message in messages
      message = "<@#{envelope.user.id}>: #{message}" if envelope.room[0] is 'D'
      @client.send(envelope, message)


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

    # Hubot expects this format for TextMessage Listener
    bot.room = channel.id if bot
    user.room = channel.id if user

    # Direct messages
    if channel.id[0] is 'D'
      text = "#{@robot.name} #{text}"     # If this is a DM, pretend it was addressed to us
      channel.name ?= channel._modelName  # give the channel a name


    # Send to Hubot based on message type
    switch subtype

      when 'bot_message'
        @robot.logger.debug "#{bot.name} has joined #{channel.name}"
        @receive new Message bot

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
        @robot.logger.debug "Received message: '#{text}' in channel: #{channel.name}, from: #{user.name}"
        @receive new TextMessage(user, text, message.ts)



module.exports = SlackBot