{Robot, Adapter, TextMessage} = require 'hubot'
SlackClient = require 'slack-client'
Util = require 'util'

class SlackBot extends Adapter
  constructor: (robot) ->
    super robot

  run: ->
    # Take our options from the environment, and set otherwise suitable defaults
    options = 
      token: process.env.HUBOT_SLACK_TOKEN
      autoReconnect: true
      autoMark: true

    @robot.logger.info Util.inspect(options)
    return @robot.logger.error "No services token provided to Hubot" unless options.token

    @options = options

    # Create our slack client object
    @client = new SlackClient options.token, options.autoReconnect, options.autoMark

    # Setup event handlers
    # TODO: I think hubot would like to know when people come online
    # TODO: Handle eventual events at (re-)connection time for unreads and provide a config for whether we want to process them
    @client.on 'error', @.error
    @client.on 'loggedIn', @.loggedIn
    @client.on 'open', @.open
    @client.on 'close', @.close
    @client.on 'message', @.message

    # Start logging in
    @client.login()

  error: (error) =>
    @robot.logger.error "Received error #{error.toString()}"

  loggedIn: (self, team) =>
    @robot.logger.info "Logged in as #{self.name} of #{team.name}, but not yet connected"

    # Provide our name to Hubot
    @robot.name = self.name

  open: =>
    @robot.logger.info 'Slack client connected'

    # Tell Hubot we're connected so it can load scripts
    @emit "connected"

  close: =>
    @robot.logger.info 'Slack client closed'

  message: (message) =>
    if message.hidden then return
    if not message.text and not message.attachments then return

    channel = @client.getChannelGroupOrDMByID message.channel
    user = @client.getUserByID message.user
    # TODO: Handle message.username for bot messages?
    # TODO: Do we need to ignore our own messages? Probably!

    # Build message text to respond to, including all attachments
    txt = ''
    if message.text then txt += message.text
    
    if message.attachments
      for k, attach of message.attachments
        if k > 0 then txt += "\n"
        txt += attach.fallback

    # TODO: Need to process the user into a full hubot user using @robot.brain.userForId user etc

    @robot.logger.debug "Received message: #{txt} in channel: #{channel.name}, from: #{user.name}"

    @receive new TextMessage(user, txt)

  # TODO: Send

  # TODO: Reply

  # TODO: Topic

exports.use = (robot) ->
  new SlackBot robot
