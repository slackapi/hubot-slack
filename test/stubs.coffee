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
  @stubs.user =
    name: 'name'
    real_name: 'real name'
    id: 'U123'
    profile:
      first_name: 'real'
      last_name: 'name'
      email: 'email@example.com'
  @stubs.self =
    name: 'self'
    real_name: 'self this'
    id: 'U456'
    profile:
      first_name: 'self'
      last_name: 'this'
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
      users: [@stubs.user, @stubs.self]
      dms: [
        name: 'user2'
        id: 'D5432'
      ]
    rtm:
      dataStore:
        users: [@stubs.user, @stubs.self]
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
  @stubs.callback = do ->
    return "done"

  # Generate a new slack instance for each test.
  @slackbot = new SlackBot @stubs.robot, token: 'xoxb-faketoken'
  _.merge @slackbot.client, @stubs.client

  @formatter = new SlackFormatter @stubs.client.dataStore

  @client = new SlackClient token: 'xoxb-faketoken'