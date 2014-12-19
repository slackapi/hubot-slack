# Setup stubs used by the other tests

{SlackBot} = require '../index'
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
    send: (msg) -> msg
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
    getUserByID: (id) =>
      for user in @stubs.client.users
        return user if user.id is id
    getChannelByID: (id) =>
      @stubs.channel if @stubs.channel.id == id
    getChannelGroupOrDMByID: (id) =>
      @stubs.channel if @stubs.channel.id == id
    getChannelGroupOrDMByName: (name) =>
      @stubs.channel if @stubs.channel.name == name
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
    robot

# Generate a new slack instance for each test.
beforeEach ->
  @slackbot = new SlackBot @stubs.robot
  @slackbot.client = @stubs.client
  @slackbot.loggedIn @stubs.self, @stubs.team
