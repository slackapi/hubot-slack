{RtmClient, WebClient} = require '@slack/client'
SlackFormatter = require './formatter'
_ = require 'lodash'

class SlackClient

  constructor: (options, robot) ->

    @robot = robot

    @robot.logger.debug "slack rtm client options: #{JSON.stringify(options.rtm)}"

    # RTM is the default communication client
    @rtm = new RtmClient options.token, options.rtm

    @rtmStartOpts = options.rtmStart || {}

    # Web is the fallback for complex messages
    @web = new WebClient options.token

    # Message formatter
    @format = new SlackFormatter(@rtm.dataStore)

    # Track listeners for easy clean-up
    @listeners = []

    @returnRawText = !options.noRawText

  ###
  Open connection to the Slack RTM API
  ###
  connect: ->
    @robot.logger.debug "slack rtm start with options: #{JSON.stringify(@rtmStartOpts)}"
    @rtm.start(@rtmStartOpts)


  ###
  Slack RTM event delegates
  ###
  on: (name, callback) ->
    @listeners.push(name)

    # override message to format text
    if name is "message"
      @rtm.on name, (message) =>
        {user, channel, bot_id} = message

        message.rawText = message.text
        message.returnRawText = @returnRawText
        message.text = @format.incoming(message)
        message.user = @rtm.dataStore.getUserById(user) if user
        message.bot = @rtm.dataStore.getBotById(bot_id) if bot_id
        message.channel = @rtm.dataStore.getChannelGroupOrDMById(channel) if channel
        callback(message)

    else
      @rtm.on(name, callback)


  ###
  Disconnect from the Slack RTM API and remove all listeners
  ###
  disconnect: ->
    @rtm.removeListener(name) for name in @listeners
    @listeners = [] # reset


  ###
  Set a channel's topic
  ###
  setTopic: (id, topic) ->
    channel = @rtm.dataStore.getChannelGroupOrDMById(id)
    @robot.logger.debug topic

    type = channel.getType()
    switch type
      when "channel" then @web.channels.setTopic(id, topic)
      # some groups are private channels which have a topic
      # some groups are MPIMs which do not
      when "group"
          @web.groups.setTopic id, topic, (err,res) =>
            if (err || !res.ok) then @robot.logger.debug "Cannot set topic in MPIM"
      else @robot.logger.debug "Cannot set topic in "+type


  ###
  Send a message to Slack using the best client for the message type
  ###
  send: (envelope, message) ->
    if envelope.room
      room = envelope.room
    else if envelope.id #Maybe we were sent a user object or channel object. Use the id, in that case.
      room = envelope.id

    @robot.logger.debug "Sending to #{room}: #{message}"

    options = { as_user: true, link_names: 1, thread_ts: envelope.message?.thread_ts }

    if typeof message isnt 'string'
      @web.chat.postMessage(room, message.text, _.defaults(message, options))
    else
      @web.chat.postMessage(room, message, options)


module.exports = SlackClient
