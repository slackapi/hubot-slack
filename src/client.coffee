{RtmClient, WebClient} = require '@slack/client'
SlackFormatter = require './formatter'
_ = require 'lodash'
Promise = require 'bluebird'

class SlackClient
  @PAGE_SIZE = 100

  ###*
  # @param {Object} options - Configuration options for this SlackClient instance
  # @param {string} options.token - Slack API token for authentication
  # @param {Object} [options.rtm={}] - Configuration options for owned RtmClient instance
  # @param {Object} [options.rtmStart={}] - Configuration options for RtmClient#start() method
  # @param {boolean} [options.noRawText=false] - Whether or not message objects should contain a `rawText` property with
  # the unformatted message text
  # @param {Robot} robot - Hubot robot instance
  ###
  constructor: (options, robot) ->

    @robot = robot

    # RTM is the default communication client
    @robot.logger.debug "slack rtm client options: #{JSON.stringify(options.rtm)}"
    # NOTE: the recommended initialization options include { dataStore: false, useRtmConnect: true }
    # but because this library exposes the @rtm.dataStore property, we cannot use those settings without breaking
    # the API for users.
    @rtm = new RtmClient options.token, options.rtm
    @rtmStartOpts = options.rtmStart || {}

    # Web is the fallback for complex messages
    @web = new WebClient options.token

    # Message formatter
    # Leaving the @format property here for backwards compatibility, but it is no longer used internally.
    @format = new SlackFormatter(@rtm.dataStore, @robot)

    # Message handler
    @rtm.on 'message', @messageWrapper, this
    @messageHandler = undefined

    @returnRawText = !options.noRawText

  ###*
  # Open connection to the Slack RTM API
  ###
  connect: ->
    @robot.logger.debug "slack rtm start with options: #{JSON.stringify(@rtmStartOpts)}"
    @rtm.start(@rtmStartOpts)

  ###*
  # Event handler for Slack RTM events with "message" type
  #
  # @param {Object} message_event - A Slack event of type `message`. See <https://api.slack.com/events/message>
  ###
  messageWrapper: (message_event) ->
    if @messageHandler
      # {user, channel, bot_id} = message_event

      # fetch full representations of the user, bot, and channel
      # TODO: implement caching store for this data
      # NOTE: can we delay these fetches until they are actually necessary? for some types of messages, they
      # will never be needed
      # NOTE: all we ever use from channel is the id and iff its a TextMessage the is_im property
      # NOTE: fetches will likely need to take place later after formatting if any user or channel mentions are found
      fetches = {};
      fetches.user = @web.users.info(user) if message_event.user
      fetches.channel = @web.conversations.info(channel) if message_event.channel
      fetches.bot = @web.bots.info(bot_id) if message_event.bot_id

      Promise.props(fetches).then((fetched) ->
        message_event.returnRawText = @returnRawText

        # messages sent from human users, apps with a bot user and using the xoxb token, and
        # slackbot have the user property
        message_event.user = fetched.user if fetched.user

        # bot_id exists on all messages with subtype bot_message
        # these messages only have a user property if sent from a bot user (xoxb token). therefore
        # the above assignment will not happen for all messages from custom integrations or apps without a bot user
        message_event.bot = fetched.bot if fetched.bot

        message_event.channel = fetched.channel if fetched.channel
        @messageHandler(message_event)
      )


  ###*
  # Set message handler
  ###
  onMessage: (callback) ->
    @messageHandler = callback if @messageHandler != callback

  ###*
  # Attach event handlers to the RTM stream
  # @deprecated This method is being removed without a replacement in the next major version.
  ###
  on: (type, callback) ->
    @robot.logger.warning "SlackClient#on() is a deprecated method and will be removed in the next major version " +
      "of hubot-slack. It is recommended not to use event handlers on the Slack clients directly. Please file an " +
      "issue for any specific event type you need.\n" +
      "Issue tracker: <https://github.com/slackapi/hubot-slack/issues>\n" +
      "Event type: #{type}\n"
    @rtm.on(type, callback)

  ###*
  # Disconnect from the Slack RTM API
  ###
  disconnect: ->
    @rtm.disconnect()
    # NOTE: removal of event listeners possibly does not belong in disconnect, because they are not added in connect.
    @rtm.removeAllListeners()

  ###*
  # Set a channel's topic
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

  ###*
  # Send a message to Slack using the best client for the message type
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

  ###*
  # Fetch users from Slack API (using pagination) and invoke callback
  ###
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
