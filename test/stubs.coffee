# Setup stubs used by the other tests

SlackBot = require '../src/bot'
SlackFormatter = require '../src/formatter'
SlackClient = require '../src/client'
{EventEmitter} = require 'events'
# Use Hubot's brain in our stubs
{Brain, Robot} = require 'hubot'
_ = require 'lodash'

# Stub a few interfaces to grease the skids for tests. These are intentionally
# as minimal as possible and only provide enough to make the tests possible.
# Stubs are recreated before each test.
beforeEach ->
  @stubs = {}

  @stubs.send = (room, msg, opts) =>
    @stubs._room = room
    @stubs._opts = opts
    if /^[UD@][\d\w]+/.test(room)
      @stubs._dmmsg = msg
    else
      @stubs._msg = msg
    msg

  @stubs.channel =
    name: 'general'
    id: 'C123'
    sendMessage: (msg) -> msg
    getType: -> 'channel'
  @stubs.DM =
    name: 'User'
    id: 'D1232'
    sendMessage: (msg) -> msg
    getType: -> 'dm'
  @stubs.group =
    name: 'Group'
    id: 'G12324'
    sendMessage: (msg) -> msg
    getType: -> 'group'
  @stubs.user =
    name: 'name'
    id: 'U123'
    profile:
      email: 'email@example.com'
  @stubs.bot =
    name: 'testbot'
    id: 'B123'
  @stubs.userperiod =
    name: 'name.lname'
    id: 'U124'
    profile:
      email: 'name.lname@example.com'
  @stubs.userhyphen =
    name: 'name-lname'
    id: 'U125'
    profile:
      email: 'name-lname@example.com'
  @stubs.self =
    name: 'self'
    id: 'U456'
    bot_id: 'B456'
    profile:
      email: 'self@example.com'
  @stubs.self_bot =
    name: 'self'
    id: 'B456'
    profile:
      email: 'self@example.com'
  @stubs.team =
    name: 'Example Team'
  # Slack client
  @stubs.client =

    dataStore:
      getUserById: (id) =>
        for user in @stubs.client.dataStore.users
          return user if user.id is id
      getBotById: (id) =>
        for bot in @stubs.client.dataStore.bots
          return bot if bot.id is id
      getUserByName: (name) =>
        for user in @stubs.client.dataStore.users
          return user if user.name is name
      getChannelById: (id) =>
        @stubs.channel if @stubs.channel.id == id
      getChannelGroupOrDMById: (id) =>
        @stubs.channel if @stubs.channel.id == id
      getChannelGroupOrDMByName: (name) =>
        return @stubs.channel if @stubs.channel.name == name
        for dm in @stubs.client.dataStore.dms
          return dm if dm.name is name
      users: [@stubs.user, @stubs.self, @stubs.userperiod, @stubs.userhyphen]
      bots: [@stubs.bot]
      dms: [
        name: 'user2'
        id: 'D5432'
      ]
  @stubs.rtm =
    login: =>
      @stubs._connected = true
    on: (name, callback) =>
      console.log("#####")
      console.log(name)
      console.log(callback)
      callback(name)
    removeListener: (name) =>
    sendMessage: (msg, room) =>
      @stubs.send room, msg
    dataStore:
      getUserById: (id) =>
        switch id
          when @stubs.user.id then @stubs.user
          when @stubs.bot.id then @stubs.bot
          when @stubs.self.id then @stubs.self
          when @stubs.self_bot.id then @stubs.self_bot
          else undefined
      getChannelByName: (name) =>
        switch name
          when 'known_room' then {id: 'C00000004'}
          else undefined
      getChannelGroupOrDMById: (id) =>
        switch id
          when @stubs.channel.id then @stubs.channel
          when @stubs.DM.id then @stubs.DM
  @stubs.chatMock =
    postMessage: (msg, room, opts) =>
      @stubs.send(msg, room, opts)
  @stubs.channelsMock =
    setTopic: (id, topic) =>
      @stubs._topic = topic
  # Hubot.Robot instance
  @stubs.robot = do ->
    robot = new EventEmitter
    # noop the logging
    robot.logger =
      logs: {}
      log: (type, message) ->
        @logs[type] ?= []
        @logs[type].push(message)
      info: (message) ->
        @log('info', message)
      debug: (message) ->
        @log('debug', message)
      error: (message) ->
        @log('error', message)
    # record all received messages
    robot.received = []
    robot.receive = (msg) ->
      @received.push msg
    # attach a real Brain to the robot
    robot.brain = new Brain robot
    robot.name = 'bot'
    robot.listeners = []
    robot.listen = Robot.prototype.listen.bind(robot)
    robot.react = Robot.prototype.react.bind(robot)
    robot
  @stubs.callback = do ->
    return "done"

  @stubs.receiveMock =
    receive: (message, user) =>
      @stubs._received = message

  # Generate a new slack instance for each test.
  @slackbot = new SlackBot @stubs.robot, token: 'xoxb-faketoken'
  _.merge @slackbot.client, @stubs.client
  _.merge @slackbot.client.rtm, @stubs.rtm
  _.merge @slackbot.client.web.chat, @stubs.chatMock
  _.merge @slackbot.client.web.channels, @stubs.channelsMock
  _.merge @slackbot, @stubs.receiveMock
  @slackbot.self = @stubs.self

  @formatter = new SlackFormatter @stubs.client.dataStore

  @client = new SlackClient {token: 'xoxb-faketoken'}, @stubs.robot
  _.merge @client.rtm, @stubs.rtm
  _.merge @client.web.chat, @stubs.chatMock
  _.merge @client.web.channels, @stubs.channelsMock
