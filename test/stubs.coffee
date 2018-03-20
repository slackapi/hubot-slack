# Setup stubs used by the other tests

Promise = require 'bluebird'
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

  # These objects are of conversation shape: https://api.slack.com/types/conversation
  @stubs.channel =
    id: 'C123'
    name: 'general'
  @stubs.DM =
    id: 'D1232'
    is_im: true
  @stubs.group =
    id: 'G12324'

  # These objects are of user shape: https://api.slack.com/types/user
  @stubs.user =
    id: 'U123'
    name: 'name' # NOTE: this property is dynamic and should only be used for display purposes
    real_name: 'real_name'
    profile:
      email: 'email@example.com'
    misc: 'misc'
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
  @stubs.usernoprofile =
    name: 'name'
    real_name: 'real_name'
    id: 'U126'
    misc: 'misc'
  @stubs.usernoemail =
    name: 'name'
    real_name: 'real_name'
    id: 'U126'
    profile:
      foo: 'bar'
    misc: 'misc'

  @stubs.bot =
    name: 'testbot'
    id: 'B123'
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
  @stubs.org_user_not_in_workspace =
    name: 'name'
    id: 'W123'
    profile:
      email: 'org_not_in_workspace@example.com'
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
    start: =>
      @stubs._connected = true
    disconnect: =>
      @stubs._connected = false
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
      getChannelGroupOrDMById: (id) =>
        switch id
          when @stubs.channel.id then @stubs.channel
          when @stubs.DM.id then @stubs.DM
  @stubs.chatMock =
    postMessage: (msg, room, opts) =>
      @stubs.send(msg, room, opts)
  @stubs.conversationsMock =
    setTopic: (id, topic) =>
      @stubs._topic = topic
    info: (conversationId) =>
      if conversationId == @stubs.channel.id
        return Promise.resolve(@stubs.channel)
      else if conversationId == @stubs.DM.id
        return Promise.resolve(@stubs.DM)
      else
        return Promise.reject(new Error('conversationsMock could not match conversation ID'))
  @stubs.usersMock =
    list: (opts, cb) =>
      @stubs._listCount = if @stubs?._listCount then @stubs._listCount + 1 else 1
      return cb(new Error('mock error')) if @stubs?._listError
      if opts?.cursor == 'mock_cursor'
        cb(null, @stubs.userListPageLast)
      else
        cb(null, @stubs.userListPageWithNextCursor)
    info: (userId) =>
      if userId == @stubs.user.id
        return Promise.resolve(@stubs.user)
      else
        return Promise.reject(new Error('usersMock could not match user ID'))
  @stubs.userListPageWithNextCursor = {
    members: [{ id: 1 }, { id: 2 }]
    response_metadata: {
      next_cursor: 'mock_cursor'
    }
  }
  @stubs.userListPageLast = {
    members: [{ id: 3 }]
    response_metadata: {
      next_cursor: ''
    }
  }

  @stubs.responseUsersList =
    ok: true
    members: [@stubs.user, @stubs.userperiod]
  @stubs.wrongResponseUsersList =
    ok: false

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
      warning: (message) ->
        @log('warning', message)
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
  _.merge @slackbot.client.web.conversations, @stubs.conversationsMock
  _.merge @slackbot, @stubs.receiveMock
  _.merge @slackbot.client.web.users, @stubs.usersMock
  @slackbot.self = @stubs.self

  @formatter = new SlackFormatter @stubs.client.dataStore

  @client = new SlackClient {token: 'xoxb-faketoken'}, @stubs.robot
  _.merge @client.rtm, @stubs.rtm
  _.merge @client.web.chat, @stubs.chatMock
  _.merge @client.web.conversations, @stubs.conversationsMock
  _.merge @client.web.users, @stubs.usersMock
