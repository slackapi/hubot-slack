Robot   = require('hubot').Robot
Adapter = require('hubot').Adapter
TextMessage = require('hubot').TextMessage
HTTPS = require 'https'

class Slack extends Adapter
  log: console.log.bind console
  logError: console.error.bind console

  send: (params, strings...) ->
    @log "Sending message"

    user = @userFromParams(params)

    strings.forEach (str) =>
      str = @escapeHtml str

      args = JSON.stringify({"channel": user.reply_to, "text": str, username: @robot.name})
      @post "/services/hooks/hubot", args

  reply: (params, strings...) ->
    @log "Sending reply"

    user = @userFromParams(params)
    strings.forEach (str) =>
      @send params, "#{user.name}: #{str}"

  topic: (params, strings...) ->
    # TODO: Set the topic

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


  userFromParams: (params) ->
    # hubot < 2.4.2: params = user
    # hubot >= 2.4.2: params = {user: user, ...}
    params = if params.user then params.user else params

    # Ghetto hack to make robot.messageRoom work with Slack's adapter
    #
    # Note: Slack's API here uses rooom ID's, not room names. They look
    # something like C0capitallettersandnumbershere
    params.reply_to ||= params.room

    params

  parseOptions: ->
    @options =
      token:   process.env.HUBOT_SLACK_TOKEN or null
      team:    process.env.HUBOT_SLACK_TEAM or null
      name:    process.env.HUBOT_SLACK_BOTNAME or 'slackbot'

  getMessageFromRequest: (req) ->
    # Parse the payload
    hubot_msg = req.param('text')
    return unless hubot_msg

    @unescapeHtml hubotMsg

  getAuthorFromRequest: (req) ->
    from = req.param('user_id')
    from_name = req.param('user_name')
    channel = req.param('channel_id')
    channel_name = req.param('channel_name')

    # Construct an author object
    author = {}
    author.id = from
    author.name = from_name
    author.reply_to = channel
    author.room = channel_name

    author

  run: ->
    self = @

    @parseOptions()
    @log "Slack adapter options:", @options

    unless @options.token
      @logError "No services token provided to Hubot"
      return

    unless @options.team
      @logError "No team provided to Hubot"
      return

    # Listen to incoming webhooks from slack
    self.robot.router.post "/hubot/slack-webhook", (req, res) ->
      self.log "Incoming message received"

      hubot_msg = self.getMessageFromRequest req
      author = self.getAuthorFromRequest req

      if hubot_msg and author
        # Pass to the robot
        self.log "Received #{hubot_msg} from #{author.name}"
        self.receive new TextMessage(author, hubot_msg)

      # Just send back an empty reply, since our actual reply,
      # if any, will be async above
      res.end ""

    # Provide our name to Hubot
    self.robot.name = @options.name

    # Tell Hubot we're connected so it can load scripts
    @log "Successfully 'connected' as", self.robot.name
    self.emit "connected"

  # Convenience HTTP Methods for sending data back to slack
  get: (path, callback) ->
    @request "GET", path, null, callback

  post: (path, body, callback) ->
    @request "POST", path, body, callback

  request: (method, path, body, callback) ->
    self = @

    #console.log method, path, body
    host = @options.team + '.slack.com'
    headers = "Host": host

    path += "?token=" + @options.token

    req_options =
      "agent"  : false
      "hostname"   : host
      "port"   : 443
      "path"   : path
      "method" : method
      "headers": headers

    if method is "POST"
      headers["Content-Type"] = "application/x-www-form-urlencoded"
      req_options.headers["Content-Length"] = body.length

    request = HTTPS.request req_options, (response) ->
      data = ""
      response.on "data", (chunk) ->
        data += chunk

      response.on "end", ->
        if response.statusCode >= 400
          self.logError "Slack services error: #{response.statusCode}"
          self.logError data

        #console.log "HTTPS response:", data
        if callback
          callback null, data

        response.on "error", (err) ->
          self.logError "HTTPS response error:", err
          if callback
            callback err, null

    if method is "POST"
      request.end(body, 'binary')
    else
      request.end()

    request.on "error", (err) ->
      self.logError "HTTPS request error:", err
      self.logError err.stack
      if callback
        callback err

exports.use = (robot) ->
  new Slack robot
