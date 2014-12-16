###################################################################
# Setup the tests
###################################################################
should = require 'should'

# Import our hero. Noop logging so that we don't clutter the test output
{SlackBot} = require '../src/slack'

# Stub a few interfaces to grease the skids for tests. These are intentionally
# as minimal as possible and only provide enough to make the tests possible.
# Stubs are recreated before each test.
stubs = null
beforeEach ->
  stubs =
    # Slack client
    channel:
      send: (msg) -> msg
    client:
      getUserByID: (id) ->
        {name: 'name', email_address: 'email@example.com'}
      getChannelGroupOrDMByName: () ->
        stubs.channel
    # Hubot.Robot instance
    robot:
      logger:
        info: ->
        debug: ->

# Generate a new slack instance for each test.
slackbot = null
beforeEach ->
  slackbot = new SlackBot stubs.robot
  slackbot.client = stubs.client


###################################################################
# Start the tests
###################################################################
describe 'Adapter', ->
  it 'Should initialize with a robot', ->
    slackbot.robot.should.eql stubs.robot

describe 'Login', ->
  it 'Should set the robot name', ->
    team =
      name: 'Test Team'
    user =
      name: 'bot'
    slackbot.loggedIn(user, team)
    slackbot.robot.name.should.equal 'bot'

describe 'Removing message formatting', ->

  it 'Should do nothing if there are no user links', ->
    foo = slackbot.removeFormatting 'foo'
    foo.should.equal 'foo'

  it 'Should change <@U1234> links to @name', ->
    foo = slackbot.removeFormatting 'foo <@U123> bar'
    foo.should.equal 'foo @name bar'

  it 'Should change <@U1234|label> links to label', ->
    foo = slackbot.removeFormatting 'foo <@U123|label> bar'
    foo.should.equal 'foo label bar'

  it 'Should change multiple links at once', ->
    foo = slackbot.removeFormatting 'foo <@U123|label> bar <@U123>'
    foo.should.equal 'foo label bar @name'

describe 'Send Messages', ->
  it 'Should send multiple messages', ->
    sentMessages = slackbot.send {room: 'room-name'}, 'one', 'two', 'three'
    sentMessages.length.should.equal 3

  it 'Should split long messages', ->
    lines = 'Hello, Slackbot\nHow are you?\n'
    # Make a very long message
    msg = lines
    len = 10000
    msg += lines while msg.length < len

    sentMessages = slackbot.send {room: 'room-name'}, msg
    sentMessage = sentMessages.pop()
    sentMessage.length.should.equal Math.ceil(len / SlackBot.MAX_MESSAGE_LENGTH)

  it 'Should try to split on word breaks', ->
    msg = 'Foo bar baz'
    slackbot.constructor.MAX_MESSAGE_LENGTH = 10
    sentMessages = slackbot.send {room: 'room-name'}, msg
    sentMessage = sentMessages.pop()
    sentMessage.length.should.equal 2

  it 'Should split into max length chunks if there are no breaks', ->
    msg = 'Foobar'
    slackbot.constructor.MAX_MESSAGE_LENGTH = 3
    sentMessages = slackbot.send {room: 'room-name'}, msg
    sentMessage = sentMessages.pop()
    sentMessage.should.eql ['Foo', 'bar']
