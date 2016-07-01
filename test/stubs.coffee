# Setup stubs used by the other tests

SlackBot = require '../src/bot'
{EventEmitter} = require 'events'
# Use Hubot's brain in our stubs
{Brain} = require 'hubot'

# Stub a few interfaces to grease the skids for tests. These are intentionally
# as minimal as possible and only provide enough to make the tests possible.
# Stubs are recreated before each test.
beforeEach ->
  @stubs = {}
  @stubs.channel =
    name: 'general'
    id: 'C123'
    sendMessage: (msg) -> msg
  @stubs.user =
    name: 'name'
    id: 'U123'
    profile:
      email: 'email@example.com'
  @stubs.self =
    name: 'self'
    id: 'U456'
    profile:
      email: 'self@example.com'
  @stubs.team =
    name: 'Example Team'
  # Slack client
  @stubs.client =
    sendMessage: (msg, env) => 
      if /user/.test(env)
        @stubs._dmmsg = msg
      else
      @stubs._msg = msg

    dataStore:
      getUserById: (id) =>
        for user in @stubs.client.dataStore.users
          return user if user.id is id
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
      openDM: (user_id, callback) =>
        user = @stubs.client.dataStore.getUserById user_id
        @stubs.client.dataStore.dms.push
          name: user.name
          id: 'D1234'
        callback?()
      users: [@stubs.user, @stubs.self]
      dms: [
        name: 'user2'
        id: 'D5432'
      ]
  # Hubot.Robot instance
  @stubs.robot = do ->
    robot = new EventEmitter
    # noop the logging
    robot.logger =
      info: ->
      debug: ->
    # record all received messages
    robot.received = []
    robot.receive = (msg) ->
      @received.push msg
    # attach a real Brain to the robot
    robot.brain = new Brain robot
    robot.name = 'bot'
    robot

# Generate a new slack instance for each test.
beforeEach ->
  @slackbot = new SlackBot @stubs.robot, token: 'xoxb-faketoken'
  @slackbot.run