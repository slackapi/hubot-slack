Robot   = require('hubot').Robot
Adapter = require('hubot').Adapter
TextMessage = require('hubot').TextMessage
HTTPS = require 'https'

class Slack extends Adapter
   send: (params, strings...) ->
      console.log "Sending message"

      user = @userFromParams(params)
      strings.forEach (str) =>
         args = JSON.stringify({"channel": user.reply_to, "text": str})
         @post "/services/hooks/hubot", args

   reply: (params, strings...) ->
      user = @userFromParams(params)
      strings.forEach (str) =>
         @send params, "#{user.name}: #{str}"

   userFromParams: (params) ->
      # hubot < 2.4.2: params = user
      # hubot >= 2.4.2: params = {user: user, ...}
      if params.user then params.user else params

   run: ->
      self = @

      @options =
         token:   process.env.HUBOT_SLACK_TOKEN
         team:    process.env.HUBOT_SLACK_TEAM
         name:    process.env.HUBOT_SLACK_BOTNAME or 'slackbot'
      console.log "Slack adapter options:", @options

      # Listen to incoming webhooks from slack
      self.robot.router.post "/hubot/slack-webhook", (req, res) ->
         console.log "Incoming message received"

         # Parse the payload
         from = req.param('user_id')
         from_name = req.param('user_name')
         channel = req.param('channel_id')
         channel_name = req.param('channel_name')
         hubot_msg = req.param('text')

         # Construct an author object
         author = {}
         author.id = from
         author.name = from_name
         author.reply_to = channel
         author.room = channel_name

         # Pass to the robot
         self.receive new TextMessage(author, hubot_msg)

         # Just send back an empty reply, since our actual reply,
         # if any, will be async above
         res.end ""

      # Provide our name to Hubot
      self.robot.name = options.name

      # Tell Hubot we're connected so it can load scripts
      self.emit "connected"

   # Convenience HTTP Methods for sending data back to slack
   get: (path, callback) ->
      @request "GET", path, null, callback

   post: (path, body, callback) ->
      @request "POST", path, body, callback

   request: (method, path, body, callback) ->
      console.log method, path, body
      host = @options.team + '.dev.hny.co'
      headers = "Host": host

      unless @options.token
         console.log "No services token provided to Hubot"
         if callback
            callback "No services token provided to Hubot", null
         return

      options =
         "agent"  : false
         "host"   : host
         "port"   : 443
         "path"   : path += "?token=#{@options.token}"
         "method" : method
         "headers": headers

      if method is "POST"
         headers["Content-Type"] = "application/x-www-form-urlencoded"
         options.headers["Content-Length"] = body.length

      request = HTTPS.request options, (response) ->
         data = ""
         response.on "data", (chunk) ->
            data += chunk

         response.on "end", ->
            if response.statusCode >= 400
               console.log "Slack services error: #{response.statusCode}"

            if callback
               callback null, data

         response.on "error", (err) ->
            if callback
               callback err, null

      if method is "POST"
         request.end(body, 'binary')
      else
         request.end()

      request.on "error", (err) ->
         console.log err
         console.log err.stack
         callback err

exports.use = (robot) ->
   new Slack robot