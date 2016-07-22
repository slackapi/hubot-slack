# Setup stubs used by the other tests

SlackBot = require '../src/bot'
SlackFormatter = require '../src/formatter'
SlackClient = require '../src/client'
{EventEmitter} = require 'events'
# Use Hubot's brain in our stubs
{Brain} = require 'hubot'
_ = require 'lodash'

# Stub a few interfaces to grease the skids for tests. These are intentionally
# as minimal as possible and only provide enough to make the tests possible.
# Stubs are recreated before each test.
beforeEach ->
  @stubs = {}
  @stubs.channel =
    name: 'general'
    id: 'C123'
    sendMessage: (msg) -> msg
  @stubs.DM =
    name: 'User'
    id: 'D1232'
    sendMessage: (msg) -> msg
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
    profile:
      email: 'self@example.com'
  @stubs.team =
    name: 'Example Team'
  # Slack client
  @stubs.client =
    send: (env, msg) =>
      if /user/.test(env.room)
        @stubs._dmmsg = msg
      else
      @stubs._msg = msg

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
    sendMessage: (message, room) =>
      @stubs._msg = message
      @stubs._room = room
  @stubs.chatMock =
    postMessage: (room, messageText, message) =>
      @stubs._msg = messageText
      @stubs._room = room
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

  @formatter = new SlackFormatter @stubs.client.dataStore

  @client = new SlackClient token: 'xoxb-faketoken'
  _.merge @client.rtm, @stubs.rtm
  _.merge @client.web.chat, @stubs.chatMock
  _.merge @client.web.channels, @stubs.channelsMock