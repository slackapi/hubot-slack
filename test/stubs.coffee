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
    getUserByName: (name) =>
      for user in @stubs.client.users
        return user if user.name is name
    getChannelByID: (id) =>
      @stubs.channel if @stubs.channel.id == id
    getChannelGroupOrDMByID: (id) =>
      @stubs.channel if @stubs.channel.id == id
    getChannelGroupOrDMByName: (name) =>
      return @stubs.channel if @stubs.channel.name == name
      for dm in @stubs.client.dms
        return dm if dm.name is name
    openDM: (user_id, callback) =>
      user = @stubs.client.getUserByID user_id
      @stubs.client.dms.push {
        name: user.name,
        id: 'D1234',
        send: (msg) =>
          @stubs._msg = if @stubs._msg then @stubs._msg + msg else msg
        }
      callback?()
    users: [@stubs.user, @stubs.self]
    dms: [
      {
        name: 'user2',
        id: 'D5432',
        send: (msg) =>
          @stubs._dmmsg = if @stubs._dmmsg then @stubs._dmmsg + msg else msg
      }
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
    robot

# Generate a new slack instance for each test.
beforeEach ->
  # FIXME: this is dirty
  SlackBot.MAX_MESSAGE_LENGTH = 4000

  @slackbot = new SlackBot @stubs.robot
  @slackbot.client = @stubs.client
  @slackbot.loggedIn @stubs.self, @stubs.team
