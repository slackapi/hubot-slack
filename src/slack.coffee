{Robot, Adapter, TextMessage, EnterMessage, LeaveMessage, TopicMessage} = require 'hubot'

SlackClient = require 'slack-client'
Util = require 'util'

class SlackBot extends Adapter
  @MAX_MESSAGE_LENGTH: 4000

  constructor: (robot) ->
    @robot = robot

  run: ->
    # Take our options from the environment, and set otherwise suitable defaults
    options =
      token: process.env.HUBOT_SLACK_TOKEN
      autoReconnect: true
      autoMark: true

    return @robot.logger.error "No services token provided to Hubot" unless options.token
    return @robot.logger.error "v2 services token provided, please follow the upgrade instructions" unless (options.token.substring(0, 5) == 'xoxb-')

    @options = options

    # Create our slack client object
    @client = new SlackClient options.token, options.autoReconnect, options.autoMark

    # Setup event handlers
    # TODO: Handle eventual events at (re-)connection time for unreads and provide a config for whether we want to process them
    @client.on 'error', @.error
    @client.on 'loggedIn', @.loggedIn
    @client.on 'open', @.open
    @client.on 'close', @.close
    @client.on 'message', @.message
    @client.on 'userChange', @.userChange
    @robot.brain.on 'loaded', @.brainLoaded

    # Start logging in
    @client.login()

  error: (error) =>
    @robot.logger.error "Received error #{error.toString()}"
    @robot.logger.error error.stack
    @robot.logger.error "Exiting in 1 second"
    setTimeout process.exit.bind(process, 1), 1000

  loggedIn: (self, team) =>
    @robot.logger.info "Logged in as #{self.name} of #{team.name}, but not yet connected"

    # store a copy of our own user data
    @self = self

    # Provide our name to Hubot
    @robot.name = self.name

    for id, user of @client.users
      @userChange user

  brainLoaded: =>
    # once the brain has loaded, reload all the users from the client
    for id, user of @client.users
      @userChange user

    # also wipe out any broken users stored under usernames instead of ids
    for id, user of @robot.brain.data.users
      if id is user.name then delete @robot.brain.data.users[user.id]

  userChange: (user) =>
    newUser = {name: user.name, email_address: user.profile.email}
    if user.id of @robot.brain.data.users
      for key, value of @robot.brain.data.users[user.id]
        unless key of newUser
          newUser[key] = value
    delete @robot.brain.data.users[user.id]
    @robot.brain.userForId user.id, newUser

  open: =>
    @robot.logger.info 'Slack client now connected'

    # Tell Hubot we're connected so it can load scripts
    @emit "connected"

  close: =>
    @robot.logger.info 'Slack client closed'
    @client.removeListener 'error', @.error
    @client.removeListener 'loggedIn', @.loggedIn
    @client.removeListener 'open', @.open
    @client.removeListener 'close', @.close
    @client.removeListener 'message', @.message
    process.exit 0

  message: (msg) =>
    return if msg.hidden
    return if not msg.text and not msg.attachments

    # Ignore bot messages (TODO: make this support an option?)
    return if msg.subtype is 'bot_message'

    # Ignore message subtypes that don't have a top level user property
    return if not msg.user

    # Ignore our own messages
    return if msg.user == @self.id

    channel = @client.getChannelGroupOrDMByID msg.channel

    # Process the user into a full hubot user
    user = @robot.brain.userForId msg.user
    user.room = channel.name

    # Test for enter/leave messages
    if msg.subtype is 'channel_join' or msg.subtype is 'group_join'
      @robot.logger.debug "#{user.name} has joined #{channel.name}"
      @receive new EnterMessage user

    else if msg.subtype is 'channel_leave' or msg.subtype is 'group_leave'
      @robot.logger.debug "#{user.name} has left #{channel.name}"
      @receive new LeaveMessage user

    else if msg.subtype is 'channel_topic' or msg.subtype is 'group_topic'
      @robot.logger.debug "#{user.name} set the topic in #{channel.name} to #{msg.topic}"
      @receive new TopicMessage user, msg.topic, msg.ts

    else
      # Build message text to respond to, including all attachments
      txt = msg.getBody()

      txt = @removeFormatting txt

      @robot.logger.debug "Received message: '#{txt}' in channel: #{channel.name}, from: #{user.name}"

      # If this is a DM, pretend it was addressed to us
      if msg.getChannelType() == 'DM'
        txt = "#{@robot.name} #{txt}"

      @receive new TextMessage user, txt, msg.ts

  removeFormatting: (txt) ->
    # https://api.slack.com/docs/formatting
    txt = txt.replace ///
      <              # opening angle bracket
      ([\@\#\!])     # link type
      (\w+)          # id
      (?:\|([^>]+))? # |label (optional)
      >              # closing angle bracket
    ///g, (m, type, id, label) =>
      if label then return label

      switch type
        when '@'
          user = @client.getUserByID id
          if user
            return "@#{user.name}"
        when '#'
          channel = @client.getChannelByID id
          if channel
            return "\##{channel.name}"
        when '!'
          if id in ['channel','group','everyone']
            return "@#{id}"
      "#{type}#{id}"

    txt = txt.replace ///
      <              # opening angle bracket
      ([^>\|]+)      # link
      (?:\|([^>]+))? # label
      >              # closing angle bracket
    ///g, (m, link, label) =>
      if label
        "#{label} #{link}"
      else
        link
    txt

  send: (envelope, messages...) ->
    channel = @client.getChannelGroupOrDMByName envelope.room

    for msg in messages
      @robot.logger.debug "Sending to #{envelope.room}: #{msg}"

      if msg.length <= SlackBot.MAX_MESSAGE_LENGTH
        channel.send msg

      # If message is greater than MAX_MESSAGE_LENGTH, split it into multiple messages
      else
        submessages = []

        while msg.length > 0
          if msg.length <= SlackBot.MAX_MESSAGE_LENGTH
            submessages.push msg
            msg = ''

          else
            # Split message at last line break, if it exists
            maxSizeChunk = msg.substring(0, SlackBot.MAX_MESSAGE_LENGTH)

            lastLineBreak = maxSizeChunk.lastIndexOf('\n')
            lastWordBreak = maxSizeChunk.match(/\W\w+$/)?.index

            breakIndex = if lastLineBreak > -1
              lastLineBreak
            else if lastWordBreak
              lastWordBreak
            else
              SlackBot.MAX_MESSAGE_LENGTH

            submessages.push msg.substring(0, breakIndex)

            # Skip char if split on line or word break
            breakIndex++ if breakIndex isnt SlackBot.MAX_MESSAGE_LENGTH

            msg = msg.substring(breakIndex, msg.length)

        channel.send m for m in submessages

  reply: (envelope, messages...) ->
    @robot.logger.debug "Sending reply"

    for msg in messages
      # TODO: Don't prefix username if replying in DM
      @send envelope, "#{envelope.user.name}: #{msg}"

  topic: (envelope, strings...) ->
    channel = @client.getChannelGroupOrDMByName envelope.room
    channel.setTopic strings.join "\n"

exports.use = (robot) ->
  new SlackBot robot

# Export class for unit tests
exports.SlackBot = SlackBot
