###################################################################
# Setup the tests
###################################################################
should = require 'should'

# Import our hero. Noop logging so that we don't clutter the test output
{Slack} = require '../src/slack'
Slack::log = ->

# Stub a few interfaces to grease the skids for tests. These are intentionally
# as minimal as possible and only provide enough to make the tests possible.
# Stubs are recreated before each test.
stubs = null
beforeEach ->
  stubs =
    # Hubot.Robot instance
    robot:
      name: 'Kitt'

    # Express request object
    request: ->
      data: {}
      param: (key) ->
        @data[key]


# Generate a new slack instance for each test.
slack = null
beforeEach ->
  slack = new Slack stubs.robot


###################################################################
# Start the tests
###################################################################
describe 'Adapter', ->
  it 'Should initialize with a robot', ->
    slack.robot.name.should.eql stubs.robot.name


describe '(Un)escaping strings', ->
  # Generate strings with multiple replacement characters
  makeTestString = (character) ->
    "Hello #{character} world and #{character} again"

  escapeChars = [
    {before: '&', after: '&amp;', name: 'ampersands'}
    {before: '>', after: '&gt;', name: 'greater than signs'}
    {before: '<', after: '&lt;', name: 'less than signs'}
  ]

  for character in escapeChars
    it "Should escape #{character.name}", ->
      escaped = slack.escapeHtml(makeTestString(character.before))
      escaped.should.eql makeTestString(character.after)

    it "Should unescape #{character.name}", ->
      unescaped = slack.unescapeHtml(makeTestString(character.after))
      unescaped.should.eql makeTestString(character.before)


describe 'Getting the user from params', ->
  it 'Should support old Hubot syntax', ->
    # Old syntax does not have a `user` property
    oldParams =
      reply_to: 'Your friend'

    slack.userFromParams(oldParams).should.have.property 'reply_to', 'Your friend'

  it 'Should support new Hubot syntax', ->
    params =
      user:
        reply_to: 'Your new friend'

    slack.userFromParams(params).should.have.property 'reply_to', 'Your new friend'

  it 'Should fall back to room value for reply_to', ->
    roomParams =
      room: 'The real reply to'

    slack.userFromParams(roomParams).should.have.property 'reply_to', 'The real reply to'


describe 'Sending a message', ->
  it 'Should JSON-ify args', ->
    # Shim the post() methd to grab its args value
    slack.post = (path, args) ->
      (-> JSON.parse args).should.not.throw()

    params =
      reply_to: 'A fake room'

    args = slack.send params, 'Hello, fake world'

describe 'Parsing options', ->
  it 'Should default to the name "slackbot"', ->
    slack.parseOptions()

    slack.options.name.should.equal 'slackbot'

  it 'Should default to the "blacklist" channel mode', ->
    slack.parseOptions()

    slack.options.mode.should.equal 'blacklist'

  it 'Should default to [] for channel list', ->
    slack.parseOptions()

    slack.options.channels.should.be.instanceof(Array).and.have.lengthOf(0);

  it 'Should default to null for missing environment variables', ->
    slack.parseOptions()

    should.not.exist slack.options.token
    should.not.exist slack.options.team

  it 'Should use HUBOT_SLACK_TOKEN environment variable', ->
    process.env.HUBOT_SLACK_TOKEN = 'insecure token'
    slack.parseOptions()

    slack.options.token.should.eql 'insecure token'
    delete process.env.HUBOT_SLACK_TOKEN

  it 'Should use HUBOT_SLACK_TEAM environment variable', ->
    process.env.HUBOT_SLACK_TEAM = 'fake team'
    slack.parseOptions()

    slack.options.team.should.eql 'fake team'
    delete process.env.HUBOT_SLACK_TEAM

  it 'Should use HUBOT_SLACK_BOTNAME environment variable', ->
    process.env.HUBOT_SLACK_BOTNAME = 'Lonely Bot'
    slack.parseOptions()

    slack.options.name.should.eql 'Lonely Bot'
    delete process.env.HUBOT_SLACK_BOTNAME

  it 'Should use HUBOT_SLACK_CHANNELMODE environment variable', ->
    process.env.HUBOT_SLACK_CHANNELMODE = 'a channel mode'
    slack.parseOptions()

    slack.options.mode.should.eql 'a channel mode'
    delete process.env.HUBOT_SLACK_CHANNELMODE

  it 'Should use HUBOT_SLACK_CHANNELS environment variable', ->
    process.env.HUBOT_SLACK_CHANNELS = 'a,list,of,channels'
    slack.parseOptions()

    slack.options.channels.should.eql ['a', 'list', 'of', 'channels']
    delete process.env.HUBOT_SLACK_CHANNELS

describe 'Parsing the request', ->
  it 'Should get the message', ->
    slack.parseOptions()

    requestText = 'The message from the request'
    req = stubs.request()
    req.data.text = requestText

    slack.getMessageFromRequest(req).should.eql requestText

  it 'Should return null if the message is missing', ->
    slack.parseOptions()

    message = slack.getMessageFromRequest stubs.request()
    should.not.exist message

  it 'Should get the author', ->
    req = stubs.request()
    req.data =
      user_id: 37
      user_name: 'Luke'
      channel_id: 760
      channel_name: 'Home'

    author = slack.getAuthorFromRequest req
    author.should.include
      id: 37
      name: 'Luke'
      reply_to: 760
      room: 'Home'

  it 'Should ignore blacklisted rooms', ->
    process.env.HUBOT_SLACK_CHANNELMODE = 'blacklist'
    process.env.HUBOT_SLACK_CHANNELS = 'test'
    slack.parseOptions()

    requestText = 'The message from the request'
    req = stubs.request()
    req.data =
      channel_name: 'test'
      text: requestText

    message = slack.getMessageFromRequest req
    should.not.exist message
    delete process.env.HUBOT_SLACK_CHANNELMODE
    delete process.env.HUBOT_SLACK_CHANNELS

  it 'Should not ignore not blacklisted rooms', ->
    process.env.HUBOT_SLACK_CHANNELMODE = 'blacklist'
    process.env.HUBOT_SLACK_CHANNELS = 'test'
    slack.parseOptions()

    requestText = 'The message from the request'
    req = stubs.request()
    req.data =
      channel_name: 'not-test'
      text: requestText

    slack.getMessageFromRequest(req).should.eql requestText
    delete process.env.HUBOT_SLACK_CHANNELMODE
    delete process.env.HUBOT_SLACK_CHANNELS

  it 'Should not ignore whitelisted rooms', ->
    process.env.HUBOT_SLACK_CHANNELMODE = 'whitelist'
    process.env.HUBOT_SLACK_CHANNELS = 'test'
    slack.parseOptions()

    requestText = 'The message from the request'
    req = stubs.request()
    req.data =
      channel_name: 'test'
      text: requestText

    slack.getMessageFromRequest(req).should.eql requestText
    delete process.env.HUBOT_SLACK_CHANNELMODE
    delete process.env.HUBOT_SLACK_CHANNELS

  it 'Should ignore not whitelisted rooms', ->
    process.env.HUBOT_SLACK_CHANNELMODE = 'whitelist'
    process.env.HUBOT_SLACK_CHANNELS = 'test'
    slack.parseOptions()

    requestText = 'The message from the request'
    req = stubs.request()
    req.data =
      channel_name: 'not-test'
      text: requestText

    message = slack.getMessageFromRequest req
    should.not.exist message
    delete process.env.HUBOT_SLACK_CHANNELMODE
    delete process.env.HUBOT_SLACK_CHANNELS
