{Robot, Adapter, TextMessage} = require 'hubot'
https = require 'https'

class Slack extends Adapter
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
  send: (params, strings...) ->
    @log "Sending message"
    user = @userFromParams params

    strings.forEach (str) =>
      str = @escapeHtml str
      args = JSON.stringify
        username : @robot.name
        channel  : user.reply_to
        text     : str

      @post "/services/hooks/hubot", args

  reply: (params, strings...) ->
    @log "Sending reply"

    user = @userFromParams params
    strings.forEach (str) =>
      @send params, "#{user.name}: #{str}"

  topic: (params, strings...) ->
    # TODO: Set the topic


  ###################################################################
  # HTML helpers.
  ###################################################################
  escapeHtml: (string) ->
    string
      # Escape entities
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')

      # Linkify. We assume that the bot is well-behaved and
      # consistently sending links with the protocol part
      .replace(/((\bhttp)\S+)/g, '<$1>')

  unescapeHtml: (string) ->
    string
      # Unescape entities
      .replace(/&amp;/g, '&')
      .replace(/&lt;/g, '<')
      .replace(/&gt;/g, '>')

      # Convert markup into plain url string.
      .replace(/<((\bhttps?)[^|]+)(\|(.*))+>/g, '$1')
      .replace(/<((\bhttps?)(.*))?>/g, '$1')


  ###################################################################
  # Parsing inputs.
  ###################################################################
  userFromParams: (params) ->
    # hubot < 2.4.2: params = user
    # hubot >= 2.4.2: params = {user: user, ...}
    params = params.user or params

    # Ghetto hack to make robot.messageRoom work with Slack's adapter
    #
    # Note: Slack's API here uses rooom ID's, not room names. They look
    # something like C0capitallettersandnumbershere
    params.reply_to ||= params.room

    params

  parseOptions: ->
    @options =
      token : process.env.HUBOT_SLACK_TOKEN
      team  : process.env.HUBOT_SLACK_TEAM
      name  : process.env.HUBOT_SLACK_BOTNAME or 'slackbot'
      mode  : process.env.HUBOT_SLACK_CHANNELMODE or 'blacklist'
      channels: process.env.HUBOT_SLACK_CHANNELS?.split(',') or []

  getMessageFromRequest: (req) ->
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


  ###################################################################
  # The star.
  ###################################################################
  run: ->
    self = @
    @parseOptions()

    @log "Slack adapter options:", @options

    return @logError "No services token provided to Hubot" unless @options.token
    return @logError "No team provided to Hubot" unless @options.team

    # Listen to incoming webhooks from slack
    self.robot.router.post "/hubot/slack-webhook", (req, res) ->
      self.log "Incoming message received"

      hubotMsg = self.getMessageFromRequest req
      author = self.getAuthorFromRequest req
      author = self.robot.brain.userForId author.id, author
      author.room = req.param 'channel_name'
      author.reply_to = req.param 'channel_id'

      if hubotMsg and author
        # Pass to the robot
        self.log "Received #{hubotMsg} from #{author.name}"
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
