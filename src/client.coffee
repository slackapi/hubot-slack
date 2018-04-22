_                      = require "lodash"
Promise                = require "bluebird"
{RtmClient, WebClient} = require "@slack/client"
SlackFormatter         = require "./formatter"

class SlackClient
  ###*
  # Number used for limit when making paginated requests to Slack Web API list methods
  # @private
  ###
  @PAGE_SIZE = 100

  ###*
  # @constructor
  # @param {Object} options - Configuration options for this SlackClient instance
  # @param {string} options.token - Slack API token for authentication
  # @param {Object} [options.rtm={}] - Configuration options for owned RtmClient instance
  # @param {Object} [options.rtmStart={}] - Configuration options for RtmClient#start() method
  # @param {boolean} [options.noRawText=false] - Deprecated: All SlackTextMessages (subtype of TextMessage) will contain
  # both the formatted text property and the rawText property
  # @param {Robot} robot - Hubot robot instance
  ###
  constructor: (options, @robot) ->

    # Client initialization
    # NOTE: the recommended initialization options are `{ dataStore: false, useRtmConnect: true }`. However the
    # @rtm.dataStore property is publically accessible, so the recommended settings cannot be used without breaking
    # this object's API. The property is no longer used internally.
    @rtm = new RtmClient options.token, options.rtm
    @web = new WebClient options.token

    @robot.logger.debug "RtmClient initialized with options: #{JSON.stringify(options.rtm)}"
    @rtmStartOpts = options.rtmStart || {}

    # Message formatter
    # NOTE: the SlackFormatter class is deprecated. However the @format property is publicly accessible, so it cannot
    # be removed without breaking this object's API. The property is no longer used internally.
    @format = new SlackFormatter(@rtm.dataStore, @robot)

    # Event handling
    # NOTE: add channel join and leave events
    @rtm.on "message", @eventWrapper, this
    @rtm.on "reaction_added", @eventWrapper, this
    @rtm.on "reaction_removed", @eventWrapper, this
    @rtm.on "presence_change", @eventWrapper, this
    @eventHandler = undefined

  ###*
  # Open connection to the Slack RTM API
  #
  # @public
  ###
  connect: ->
    @robot.logger.debug "RtmClient#start() with options: #{JSON.stringify(@rtmStartOpts)}"
    @rtm.start(@rtmStartOpts)

  ###*
  # Set event handler
  #
  # @public
  # @param {SlackClient~eventHandler} callback
  ###
  onEvent: (callback) ->
    @eventHandler = callback if @eventHandler != callback

  ###*
  # Attach event handlers to the RTM stream
  # @public
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
  #
  # @public
  ###
  disconnect: ->
    @rtm.disconnect()
    # NOTE: removal of event listeners possibly does not belong in disconnect, because they are not added in connect.
    @rtm.removeAllListeners()

  ###*
  # Set a channel's topic
  #
  # @public
  # @param {string} conversationId - Slack conversation ID
  # @param {string} topic - new topic
  ###
  setTopic: (conversationId, topic) ->
    @robot.logger.debug "SlackClient#setTopic() with topic #{topic}"

    # The `conversations.info` method is used to find out if this conversation can have a topic set
    # NOTE: There's a performance cost to making this request, which can be avoided if instead the attempt to set the
    # topic is made regardless of the conversation type. If the conversation type is not compatible, the call would
    # fail, which is exactly the outcome in this implementation.
    @web.conversations.info(conversationId)
      .then (res) =>
        conversation = res.channel
        if !conversation.is_im && !conversation.is_mpim
          return @web.conversations.setTopic(conversationId, topic)
        else
          @robot.logger.debug "Conversation #{conversationId} is a DM or MPDM. " +
                              "These conversation types do not have topics."
      .catch (error) =>
        @robot.logger.error "Error setting topic in conversation #{conversationId}: #{error.message}"

  ###*
  # Send a message to Slack using the Web API.
  #
  # This method is usually called when a Hubot script is sending a message in response to an incoming message. The
  # response object has a `send()` method, which triggers execution of all response middleware, and ultimately calls
  # `send()` on the Adapter. SlackBot, the adapter in this case, delegates that call to this method; once for every item
  # (since its method signature is variadic). The `envelope` is created by the Hubot Response object.
  #
  # This method can also be called when a script directly calls `robot.send()` or `robot.adapter.send()`. That bypasses
  # the execution of the response middleware and directly calls into SlackBot#send(). In this case, the `envelope`
  # parameter is up to the script.
  #
  # The `envelope.room` property is intended to be a conversation ID. Even when that is not the case, this method will
  # makes a reasonable attempt at sending the message. If the property is set to a public or private channel name, it
  # will still work. When there's no `room` in the envelope, this method will fallback to the `id` property. That
  # affordance allows scripts to use Hubot User objects, Slack users (as obtained from the response to `users.info`),
  # and Slack conversations (as obtained from the response to `conversations.info`) as possible envelopes. In the first
  # two cases, envelope.id` will contain a user ID (`Uxxx` or `Wxxx`). Since Hubot runs using a bot token (`xoxb`),
  # passing a user ID as the `channel` argument to `chat.postMessage` (with `as_user=true`) results in a DM from the bot
  # user (if `as_user=false` it would instead result in a DM from slackbot). Leaving `as_user=true` has no effect when
  # the `channel` argument is a conversation ID.
  #
  # NOTE: This method no longer accepts `envelope.room` set to a user name. Using it in this manner will result in a
  # `channel_not_found` error.
  #
  # @public
  # @param {Object} envelope - a Hubot Response envelope
  # @param {Message} [envelope.message] - the Hubot Message that was received and generated the Response which is now
  # being used to send an outgoing message
  # @param {User} [envelope.user] - the Hubot User object representing the user who sent `envelope.message`
  # @param {string} [envelope.room] - a Slack conversation ID for where `envelope.message` was received, usually an
  # alias of `envelope.user.room`
  # @param {string} [envelope.id] - a Slack conversation ID similar to `envelope.room`
  # @param {string|Object} message - the outgoing message to be sent, can be a simple string or a key/value object of
  # optional arguments for the Slack Web API method `chat.postMessage`.
  ###
  send: (envelope, message) ->
    room = envelope.room || envelope.id
    if not room?
      @robot.logger.error "Cannot send message without a valid room. Envelopes should contain a room property set to " +
                          "a Slack conversation ID."
      return

    @robot.logger.debug "SlackClient#send() room: #{room}, message: #{message}"

    options =
      as_user: true,
      link_names: 1,
      # when the incoming message was inside a thread, send responses as replies to the thread
      # NOTE: consider building a new (backwards-compatible) format for room which includes the thread_ts.
      # e.g. "#{conversationId} #{thread_ts}" - this would allow a portable way to say the message is in a thread
      thread_ts: envelope.message?.thread_ts

    if typeof message isnt "string"
      @web.chat.postMessage(room, message.text, _.defaults(message, options))
        .catch (error) =>
          @robot.logger.error "SlackClient#send() error: #{error.message}"
    else
      @web.chat.postMessage(room, message, options)
        .catch (error) =>
          @robot.logger.error "SlackClient#send() error: #{error.message}"

  ###*
  # Fetch users from Slack API using pagination
  #
  # @public
  # @param {SlackClient~usersCallback} callback
  ###
  loadUsers: (callback) ->
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

  ###*
  # Processes events to fetch additional data or rearrange the shape of an event before handing off to the eventHandler
  #
  # @private
  # @param {SlackRtmEvent} event - One of any of the events listed in <https://api.slack.com/events> with RTM enabled.
  ###
  eventWrapper: (event) ->
    if @eventHandler
      # fetch full representations of the user, bot, channel, and potentially the item_user.
      fetches = {}
      fetches.user = @web.users.info(event.user).then((r) => r.user) if event.user
      fetches.bot = @web.bots.info(bot: event.bot_id).then((r) => r.bot) if event.bot_id
      fetches.item_user = @web.users.info(event.item_user).then((r) => r.user) if event.item_user

      # NOTE: there's a performance cost to making this request which may be avoided since the only properties used are
      # id and is_im. the former is already available, while the latter can be retreived on-demand inside the
      # SlackTextMessage#buildText() method
      fetches.channel = @web.conversations.info(event.channel).then((r) => r.channel) if event.channel

      # after fetches complete...
      Promise.props(fetches)
        .then (fetched) =>
          # start augmenting the event with the fetched data
          event.channel = fetched.channel if fetched.channel
          event.item_user = fetched.item_user if fetched.item_user

          # assigning `event.user` properly depends on how the message was sent
          if fetched.user
            # messages sent from human users, apps with a bot user and using the bot token, and slackbot have the user
            # property: this is preferred if its available
            event.user = fetched.user
          else if fetched.bot?.user_id?
            # if `event.user` isn't available and the event has a `bot_id`, then there may be a bot user associated
            # with that `bot_id`
            return @web.users.info(fetched.bot.user_id)
              .then (res) =>
                event.user = res.user
                return event
          return event

        # once the event is fully populated...
        .then (fetchedEvent) =>
          # hand the event off to the eventHandler
          try @eventHandler(fetchedEvent)
          catch error then @robot.logger.error "An error occurred while processing an RTM event: #{error.message}."

        # handle fetch errors
        .catch (error) =>
          @robot.logger.error "Incoming RTM message dropped due to error fetching info for a property: #{error.message}."

###*
# A handler for all incoming Slack events that are meaningful for the Adapter
#
# @callback SlackClient~eventHandler
# @param {Object} event
# @param {SlackUserInfo} event.user
# @param {SlackConversationInfo} event.channel
###

###*
# Callback that recieves a list of users
#
# @callback SlackClient~usersCallback
# @param {Error|null} error - an error if one occurred
# @param {Object} results
# @param {Array<SlackUserInfo>} results.members
###

module.exports = SlackClient
