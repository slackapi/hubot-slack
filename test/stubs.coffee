# Setup stubs used by the other tests

Promise = require 'bluebird'
SlackBot = require '../src/bot'
SlackFormatter = require '../src/formatter'
SlackClient = require '../src/client'
{EventEmitter} = require 'events'
{ SlackTextMessage } = require '../src/message'
# Use Hubot's brain in our stubs
{Brain, Robot} = require 'hubot'
_ = require 'lodash'
require '../src/extensions'

# Stub a few interfaces to grease the skids for tests. These are intentionally
# as minimal as possible and only provide enough to make the tests possible.
# Stubs are recreated before each test.
beforeEach ->
  @stubs = {}

  @stubs._sendCount = 0
  @stubs.send = (conversationId, text, opts) =>
    @stubs._room = conversationId
    @stubs._opts = opts
    if (/^[UD@][\d\w]+/.test(conversationId)) or (conversationId is @stubs.DM.id)
      @stubs._dmmsg = text
    else
      @stubs._msg = text
    @stubs._sendCount = @stubs._sendCount + 1

  # These objects are of conversation shape: https://api.slack.com/types/conversation
  @stubs.channel =
    id: 'C123'
    name: 'general'
  @stubs.DM =
    id: 'D1232'
    is_im: true
  @stubs.group =
    id: 'G12324',
    is_mpim: true

  # These objects are conversation IDs used to siwtch behavior of another stub
  @stubs.channelWillFailChatPost = "BAD_CHANNEL"

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
  @stubs.userdeleted =
    name: 'name'
    id: 'U127'
    deleted: true

  @stubs.bot =
    name: 'testbot'
    id: 'B123'
    user_id: 'U123'
  @stubs.undefined_user_bot =
    name: 'testbot'
    id: 'B789'
  @stubs.slack_bot =
    name: 'slackbot'
    id: 'B01'
    user_id: 'USLACKBOT'
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
  @stubs.org_user_not_in_workspace_in_channel =
    name: 'name'
    id: 'W123'
    profile:
      email: 'org_not_in_workspace@example.com'
  @stubs.team =
    name: 'Example Team'
    id: 'T123'
  @stubs.expired_timestamp = 1528238205453
  @stubs.event_timestamp = '1360782804.083113'

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
    postMessage: (conversationId, text, opts) =>
      return Promise.reject(new Error("stub error")) if conversationId is @stubs.channelWillFailChatPost
      @stubs.send(conversationId, text, opts)
      Promise.resolve()
  @stubs.conversationsMock =
    setTopic: (id, topic) =>
      @stubs._topic = topic
      if @stubs.receiveMock.onTopic? then @stubs.receiveMock.onTopic @stubs._topic
      Promise.resolve()
    info: (conversationId) =>
      if conversationId == @stubs.channel.id
        return Promise.resolve({ok: true, channel: @stubs.channel})
      else if conversationId == @stubs.DM.id
        return Promise.resolve({ok: true, channel: @stubs.DM})
      else if conversationId == 'C789'
        return Promise.resolve()
      else
        return Promise.reject(new Error('conversationsMock could not match conversation ID'))
  @stubs.botsMock =
    info: (event) =>
      botId = event.bot
      if botId == @stubs.bot.id
        return Promise.resolve({ok: true, bot: @stubs.bot})
      else if botId == @stubs.undefined_user_bot.id
        return Promise.resolve({ok: true, bot: @stubs.undefined_user_bot})
      else
        return Promise.reject(new Error('botsMock could not match bot ID'))
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
        return Promise.resolve({ok: true, user: @stubs.user})
      else if userId == @stubs.org_user_not_in_workspace.id
        return Promise.resolve({ok: true, user: @stubs.org_user_not_in_workspace})
      else if userId == 'U789'
        return Promise.resolve()
      else
        return Promise.reject(new Error('usersMock could not match user ID'))
  @stubs.userListPageWithNextCursor = {
    members: [{ id: 1 }, { id: 2 }, { id: 4, profile: { bot_id: 'B1' } }]
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
    members: []
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
    # attach a real Brain to the robot
    robot.brain = new Brain robot
    robot.name = 'bot'
    robot.listeners = []
    robot.listen = Robot.prototype.listen.bind(robot)
    robot.react = Robot.prototype.react.bind(robot)
    robot.hearReaction = Robot.prototype.hearReaction.bind(robot)
    robot.presenceChange = Robot.prototype.presenceChange.bind(robot)
    robot.fileShared = Robot.prototype.fileShared.bind(robot)
    robot
  @stubs.callback = do ->
    return "done"

  @stubs.receiveMock =
    receive: (message, user) =>
      @stubs._received = message
      if @stubs.receiveMock.onReceived? then @stubs.receiveMock.onReceived message

  # Generate a new slack instance for each test.
  @slackbot = new SlackBot @stubs.robot, token: 'xoxb-faketoken'
  _.merge @slackbot.client, @stubs.client
  _.merge @slackbot.client.rtm, @stubs.rtm
  _.merge @slackbot.client.web.chat, @stubs.chatMock
  _.merge @slackbot.client.web.users, @stubs.usersMock
  _.merge @slackbot.client.web.conversations, @stubs.conversationsMock
  _.merge @slackbot, @stubs.receiveMock
  @slackbot.self = @stubs.self

  @formatter = new SlackFormatter @stubs.client.dataStore, @stubs.robot

  @slacktextmessage = new SlackTextMessage @stubs.self, undefined, undefined, {text: undefined}, @stubs.channel.id, undefined, @slackbot.client

  @slacktextmessage_invalid_conversation = new SlackTextMessage @stubs.self, undefined, undefined, {text: undefined}, 'C888', undefined, @slackbot.client

  @client = new SlackClient {token: 'xoxb-faketoken'}, @stubs.robot
  _.merge @client.rtm, @stubs.rtm
  _.merge @client.web.chat, @stubs.chatMock
  _.merge @client.web.conversations, @stubs.conversationsMock
  _.merge @client.web.users, @stubs.usersMock
  _.merge @client.web.bots, @stubs.botsMock
