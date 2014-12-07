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
    # Hubot.Robot instance
    robot:
      logger:
        info: ->

# Generate a new slack instance for each test.
slackbot = null
beforeEach ->
  slackbot = new SlackBot stubs.robot


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
