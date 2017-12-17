{RtmClient, WebClient} = require '@slack/client'
SlackFormatter = require './formatter'
_ = require 'lodash'

class SlackClient
  @PAGE_SIZE = 100

  constructor: (options, robot) ->

    @robot = robot

    # RTM is the default communication client
    @robot.logger.debug "slack rtm client options: #{JSON.stringify(options.rtm)}"
    @rtm = new RtmClient options.token, options.rtm
    @rtmStartOpts = options.rtmStart || {}

    # Web is the fallback for complex messages
    @web = new WebClient options.token

    # Message formatter
    @format = new SlackFormatter(@rtm.dataStore)

    # Message handler
    @rtm.on 'message', @messageWrapper, this
    @messageHandler = undefined

    @returnRawText = !options.noRawText

  ###
  Open connection to the Slack RTM API
  ###
  connect: ->
    @robot.logger.debug "slack rtm start with options: #{JSON.stringify(@rtmStartOpts)}"
    @rtm.start(@rtmStartOpts)

  ###
  Slack RTM message events wrapper
  ###
  messageWrapper: (message) ->
    if @messageHandler
      {user, channel, bot_id} = message

      message.rawText = message.text
      message.returnRawText = @returnRawText
      message.text = @format.incoming(message)

      # messages sent from human users, apps with a bot user and using the xoxb token, and
      # slackbot have the user property
      message.user = @rtm.dataStore.getUserById(user) if user

      # bot_id exists on all messages with subtype bot_message
      # these messages only have a user property if sent from a bot user (xoxb token). therefore
      # the above assignment will not happen for all custom integrations or apps without a bot user
      message.bot = @rtm.dataStore.getBotById(bot_id) if bot_id

      message.channel = @rtm.dataStore.getChannelGroupOrDMById(channel) if channel
      @messageHandler(message)


  ###
  Set message handler
  ###
  onMessage: (callback) ->
    @messageHandler = callback if @messageHandler != callback

  ###
  Attach event handlers to the RTM stream
  Deprecated: This API is being removed without a replacement in the next major version.
  ###
  on: (type, callback) ->
    @robot.logger.warning 'SlackClient#on() is a deprecated method and will be removed in the next major version ' +
      'of hubot-slack. See documentaiton for a migration guide to find alternatives.'
    @rtm.on(type, callback)

  ###
  Disconnect from the Slack RTM API
  ###
  disconnect: ->
    @rtm.disconnect()
    # NOTE: removal of event listeners possibly does not belong in disconnect, because they are not added in connect.
    @rtm.removeAllListeners()


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

  loadUsers: (callback) ->
    # paginated call to users.list
    # some properties of the real results are left out because they are not used
    combinedResults = { members: [] }
    pageLoaded = (error, results) =>
      return callback(error) if error
      # merge results into combined results
      combinedResults.members.push(member) for member in results.members
      if results?.response_metadata?.next_cursor
        # fetch next page
        @web.users.list({
          limit: SlackClient.PAGE_SIZE,
          cursor: results.response_metadata.next_cursor
        }, pageLoaded)
      else
        # pagination complete, run callback with results
        callback(null, combinedResults)
    @web.users.list({ limit: SlackClient.PAGE_SIZE }, pageLoaded)


module.exports = SlackClient
