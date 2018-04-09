{RtmClient, WebClient} = require '@slack/client'
SlackFormatter = require './formatter'
_ = require 'lodash'
Promise = require 'bluebird'

class SlackClient
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

    # Event handler
    # NOTE: add channel join and leave events
    @rtm.on 'message', @eventWrapper, this
    @rtm.on 'reaction_added', @eventWrapper, this
    @rtm.on 'reaction_removed', @eventWrapper, this
    @rtm.on 'presence_change', @eventWrapper, this
    @eventHandler = undefined

  ###*
  # Open connection to the Slack RTM API
  # @public
  ###
  connect: ->
    @robot.logger.debug "slack rtm start with options: #{JSON.stringify(@rtmStartOpts)}"
    @rtm.start(@rtmStartOpts)

  ###*
  # Set event handler
  # @public
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
  # @public
  ###
  disconnect: ->
    @rtm.disconnect()
    # NOTE: removal of event listeners possibly does not belong in disconnect, because they are not added in connect.
    @rtm.removeAllListeners()

  ###*
  # Set a channel's topic
  # @public
  ###
  setTopic: (conversationId, topic) ->
    # NOTE: if channel cache is implemented, then this query should hit the cache
    @robot.logger.debug topic
    @web.conversations.info(conversationId).then((conversation) =>
      if !conversation.is_im && !conversation.is_mpim
        return @web.conversations.setTopic(conversationId, topic)
      else
        @robot.logger.debug "Cannot set topic in DM or MPIM"
    )
    .catch((error) =>
      @robot.logger.error "Error setting topic in conversation #{conversationId}: #{error.message}"
    )

  ###*
  # Send a message to Slack using the Web API
  # @public
  ###
  send: (envelope, message) ->
    # NOTE: potentially lost functionality:
    # channel = @client.getChannelGroupOrDMByName envelope.room
    # channel = @client.getChannelGroupOrDMByID(envelope.room) unless channel
    #
    # if not channel and @client.getUserByName(envelope.room)
    #   user_id = @client.getUserByName(envelope.room).id
    #   @client.openDM user_id, =>
    #     this.send envelope, messages...
    #   return
    if envelope.room
      room = envelope.room
    else if envelope.id # Maybe we were sent a user object or channel object. Use the id, in that case.
      room = envelope.id

    @robot.logger.debug "Sending to #{room}: #{message}"

    # NOTE: when posting to a DM, setting the `as_user` option to true will post as the _authenticated user_, and false
    # will post _as the bot_. its not clear what that means when using a bot token (xoxb), since its not supposed to
    # have an authenticated user like user tokens (xoxp).
    # NOTE: should the thread_ts option be directly on the envelop instead of inside envelop.message?
    options = { as_user: true, link_names: 1, thread_ts: envelope.message?.thread_ts }

    if typeof message isnt 'string'
      @web.chat.postMessage(room, message.text, _.defaults(message, options))
    else
      @web.chat.postMessage(room, message, options)

  ###*
  # Fetch users from Slack API (using pagination) and invoke callback
  # @public
  ###
  loadUsers: (callback, continueFn = @defaultContinueFn) ->
    # paginated call to users.list
    # some properties of the real results are left out because they are not used
    combinedResults = { members: [] }
    pageLoaded = (error, results) =>
      return callback(error) if error
      # merge results into combined results
      combinedResults.members.push(member) for member in results.members
      # checks if result found in results
      shouldContinue = continueFn(results.members)

      if shouldContinue && results?.response_metadata?.next_cursor
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
  # Default function for continueFn for loadUsers()
  ###
  defaultContinueFn: (combinedResults) ->
    return true

  ###*
  # Invokes callback with Slack user object for a given botId 
  ###
  findBotUser: (botId, callback) ->
    @loadUsers((err, res) => 
      if err then return callback(err)
      for member in res.members
        if member.profile?.bot_id == botId then return callback(null, member)
    , (partialResult) =>
        for member in partialResult
          if member.profile?.bot_id == botId then return false
        return true
    )

  ###*
  # Event handler for Slack RTM events
  # @private
  # @param {Object} event - A Slack event. See <https://api.slack.com/events>
  ###
  eventWrapper: (event) ->
    if @eventHandler
      # fetch full representations of the user, bot, and channel
      # TODO: implement caching store for this data
      # NOTE: can we delay these fetches until they are actually necessary? for some types of messages, they
      # will never be needed
      # NOTE: all we ever use from channel is the id and iff its a TextMessage the is_im property
      # NOTE: can we update the user entry in the brain?
      # NOTE: fetches will likely need to take place later after formatting if any user or channel mentions are found
      fetches = {};
      fetches.user = @web.users.info(event.user) if event.user
      fetches.channel = @web.conversations.info(event.channel) if event.channel
      fetches.item_user = @web.users.info(event.item_user) if event.item_user

      Promise.props(fetches).then((fetched) =>

        event.channel = fetched.channel if fetched.channel

        # this property is for reaction_added and reaction_removed events
        # previous behavior was to ignore this event entirely if the user and item_user were not in the local workspace
        event.item_user = fetched.item_user if fetched.item_user

        # User always preferred over bot
        # messages sent from human users, apps with a bot user and using the xoxb token, and
        # slackbot have the user property
        if fetched.user
          event.user = fetched.user
          return event

        else if event.bot_id
          # bot_id exists on all messages with subtype bot_message
          # these messages only have a user property if sent from a bot user (xoxb token). therefore
          # the above assignment will not happen for all messages from custom integrations or apps without a bot user
          Promise.promisify(@findBotUser, { context: @ })(event.bot_id).then((res) =>
            event.user = res
            return event
          )
      )
      .then((fetchedEvent) =>
        try @eventHandler(fetchedEvent)
        catch error then @robot.logger.error "An error occurred while processing an RTM event: #{error.message}."
      )
      .catch((error) =>
        @robot.logger.error "Incoming RTM message dropped due to error fetching info for a property: #{error.message}."
      )


module.exports = SlackClient
