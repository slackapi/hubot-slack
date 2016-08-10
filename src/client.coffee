{RtmClient, WebClient, MemoryDataStore} = require '@slack/client'
SlackFormatter = require './formatter'
_ = require 'lodash'

SLACK_CLIENT_OPTIONS =
  dataStore: new MemoryDataStore()


class SlackClient
  
  constructor: (options) ->
    _.merge SLACK_CLIENT_OPTIONS, options

    # RTM is the default communication client
    @rtm = new RtmClient options.token, options
    
    # Web is the fallback for complex messages
    @web = new WebClient options.token, options

    # Message formatter
    @format = new SlackFormatter(@rtm.dataStore)

    # Track listeners for easy clean-up
    @listeners = []


  ###
  Open connection to the Slack RTM API
  ###
  connect: ->
    @rtm.login()


  ###
  Slack RTM event delegates
  ###
  on: (name, callback) ->
    @listeners.push(name)
    
    # override message to format text
    if name is "message"
      @rtm.on name, (message) =>
        {user, channel, bot_id} = message

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
    @web.channels.setTopic(id, topic)


  ###
  Send a message to Slack using the best client for the message type
  ###
  send: (envelope, message) ->
    message = @format.outgoing(message)

    if typeof message isnt 'string'
      @web.chat.postMessage(envelope.room, message.text, _.defaults(message, {'as_user': true}))
    else if /<.+\|.+>/.test(message)
      @web.chat.postMessage(envelope.room, message, {'as_user' : true})
    else
      @rtm.sendMessage(message, envelope.room) # RTM behaves as though `as_user` is true already


module.exports = SlackClient
