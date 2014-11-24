{Robot, Adapter, TextMessage} = require 'hubot'
https = require 'https'

class Slack extends Adapter
  constructor: (robot) ->
    super robot
    @channelMapping = {}


  ###################################################################
  # Slightly abstract logging, primarily so that it can
  # be easily altered for unit tests.
  ###################################################################
  log: console.log.bind console
  logError: console.error.bind console


  ###################################################################
  # Communicating back to the chat rooms. These are exposed
  # as methods on the argument passed to callbacks from
  # robot.respond, robot.listen, etc.
  ###################################################################
  send: (envelope, strings...) ->
    @log "Sending message"
    channel = envelope.reply_to || @channelMapping[envelope.room] || envelope.room

    strings.forEach (str) =>
      str = @escapeHtml str
      args = JSON.stringify
        username     : @robot.name
        channel      : channel
        text         : str
        link_names   : @options.link_names if @options?.link_names?
        unfurl_links : @options.unfurl_links if @options?.unfurl_links?

      @post "/services/hooks/hubot", args

  reply: (envelope, strings...) ->
    @log "Sending reply"

    user_name = envelope.user?.name || envelope?.name

    strings.forEach (str) =>
      @send envelope, "#{user_name}: #{str}"

  topic: (params, strings...) ->
    # TODO: Set the topic


  custom: (message, data)->
    @log "Sending custom message"
    channel = message.reply_to || @channelMapping[message.room] || message.room
    data = [data] unless Array.isArray data
    attachments = []
    for item in data
      attachments.push
        text      : @escapeHtml item.text
        fallback  : @escapeHtml item.fallback
        pretext   : @escapeHtml item.pretext
        color     : item.color
        fields    : item.fields
        mrkdwn_in : item.mrkdwn_in
    args = JSON.stringify
      username     : message.username || @robot.name
      icon_url     : message.icon_url
      icon_emoji   : message.icon_emoji
      channel      : channel
      attachments  : attachments
      link_names   : @options.link_names if @options?.link_names?
      unfurl_links : @options.unfurl_links if @options?.unfurl_links?
    @post "/services/hooks/hubot", args
  ###################################################################
  # HTML helpers.
  ###################################################################
  escapeHtml: (string) ->
    try
      string
        # Escape entities
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')

        # Linkify. We assume that the bot is well-behaved and
        # consistently sending links with the protocol part
        .replace(/((\bhttp)\S+)/g, '<$1>')
    catch e
      @logError "Failed to escape HTML: #{e}"
      return ''

  unescapeHtml: (string) ->
    try
      string
        # Unescape entities
        .replace(/&amp;/g, '&')
        .replace(/&lt;/g, '<')
        .replace(/&gt;/g, '>')

        # Convert markup into plain url string.
        .replace(/<((\bhttps?)[^|]+)(\|(.*))+>/g, '$1')
        .replace(/<((\bhttps?)(.*))?>/g, '$1')
    catch e
      @logError "Failed to unescape HTML: #{e}"
      return ''


  ###################################################################
  # Parsing inputs.
  ###################################################################

  parseOptions: ->
    @options =
      token : process.env.HUBOT_SLACK_TOKEN
      team  : process.env.HUBOT_SLACK_TEAM
      name  : process.env.HUBOT_SLACK_BOTNAME or 'slackbot'
      mode  : process.env.HUBOT_SLACK_CHANNELMODE or 'blacklist'
      # Make sure channel settings don't include leading hashes
      channels: (process.env.HUBOT_SLACK_CHANNELS?.split(',') or []).map (channel) ->
        channel.replace /^#/, ''
      link_names: process.env.HUBOT_SLACK_LINK_NAMES or 0
      unfurl_links: process.env.HUBOT_SLACK_UNFURL_LINKS or 0

  getMessageFromRequest: (req) ->
    # Check the token
    return if not req.param('token') or (req.param('token') isnt @options.token)

    # Parse the payload
    hubotMsg = req.param 'text'
    room = req.param 'channel_name'
    mode = @options.mode
    channels = @options.channels

    @unescapeHtml hubotMsg if hubotMsg and (mode is 'blacklist' and room not in channels or mode is 'whitelist' and room in channels)

  getAuthorFromRequest: (req) ->
    # Return an author object
    id       : req.param 'user_id'
    name     : req.param 'user_name'

  userFromParams: (params) ->
    # hubot < 2.4.2: params = user
    # hubot >= 2.4.2: params = {user: user, ...}
    user = {}
    if params.user
      user = params.user
    else
      user = params

    if user.room and not user.reply_to
      user.reply_to = user.room

    user
  ###################################################################
  # The star.
  ###################################################################
  run: ->
    self = @
    @parseOptions()

    @log "Slack adapter options:", @options

    return @logError "No services token provided to Hubot" unless @options.token
    return @logError "No team provided to Hubot" unless @options.team

    @robot.on 'slack-attachment', (payload)=>
      @custom(payload.message, payload.content)

    # Listen to incoming webhooks from slack
    self.robot.router.post "/hubot/slack-webhook", (req, res) ->
      self.log "Incoming message received"

      hubotMsg = self.getMessageFromRequest req
      author = self.getAuthorFromRequest req
      author = self.robot.brain.userForId author.id, author
      author.reply_to = req.param 'channel_id'
      author.room = req.param 'channel_name'
      self.channelMapping[req.param 'channel_name'] = req.param 'channel_id'

      if hubotMsg and author
        # Pass to the robot
        self.receive new TextMessage(author, hubotMsg)

      # Just send back an empty reply, since our actual reply,
      # if any, will be async above
      res.end ""

    # Provide our name to Hubot
    self.robot.name = @options.name

    # Tell Hubot we're connected so it can load scripts
    @log "Successfully 'connected' as", self.robot.name
    self.emit "connected"


  ###################################################################
  # Convenience HTTP Methods for sending data back to slack.
  ###################################################################
  get: (path, callback) ->
    @request "GET", path, null, callback

  post: (path, body, callback) ->
    @request "POST", path, body, callback

  request: (method, path, body, callback) ->
    self = @

    host = "#{@options.team}.slack.com"
    headers =
      Host: host

    path += "?token=#{@options.token}"

    reqOptions =
      agent    : false
      hostname : host
      port     : 443
      path     : path
      method   : method
      headers  : headers

    if method is "POST"
      body = new Buffer body
      reqOptions.headers["Content-Type"] = "application/x-www-form-urlencoded"
      reqOptions.headers["Content-Length"] = body.length

    request = https.request reqOptions, (response) ->
      data = ""
      response.on "data", (chunk) ->
        data += chunk

      response.on "end", ->
        if response.statusCode >= 400
          self.logError "Slack services error: #{response.statusCode}"
          self.logError data

        #console.log "HTTPS response:", data
        callback? null, data

        response.on "error", (err) ->
          self.logError "HTTPS response error:", err
          callback? err, null

    if method is "POST"
      request.end body, "binary"
    else
      request.end()

    request.on "error", (err) ->
      self.logError "HTTPS request error:", err
      self.logError err.stack
      callback? err


###################################################################
# Exports to handle actual usage and unit testing.
###################################################################
exports.use = (robot) ->
  new Slack robot

# Export class for unit tests
exports.Slack = Slack
