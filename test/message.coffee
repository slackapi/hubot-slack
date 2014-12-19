{SlackTextMessage, SlackRawMessage, SlackBotMessage, SlackRawListener, SlackBotListener} = require '../index'

should = require 'should'

class ClientMessage
  ts = 0
  constructor: (fields = {}) ->
    @type = 'message'
    @ts = (ts++).toString()
    @[k] = val for own k, val of fields

  getBody: ->
    @text ? ""

  getChannelType: ->
    # we only simulate channels for now
    'Channel'

describe 'Receiving a Slack message', ->
  beforeEach ->
    @makeMessage = (fields = {}) =>
      msg = new ClientMessage fields
      msg.channel = @stubs.channel.id unless 'channel' of fields
      msg

  it 'should produce a SlackTextMessage', ->
    @slackbot.message @makeMessage {
      user: @stubs.user.id
      text: "Hello world"
    }
    @stubs.robot.received.should.have.length(1)
    msg = @stubs.robot.received[0]
    msg.should.be.an.instanceOf(SlackTextMessage)
    msg.text.should.equal "Hello world"

  it 'should parse the text in the SlackTextMessage', ->
    @slackbot.message @makeMessage {
      user: @stubs.user.id
      text: "Foo <@U123> bar <http://slack.com>"
    }
    @stubs.robot.received.should.have.length(1)
    msg = @stubs.robot.received[0]
    msg.should.be.an.instanceOf(SlackTextMessage)
    msg.text.should.equal "Foo @name bar http://slack.com"
    msg.rawText.should.equal "Foo <@U123> bar <http://slack.com>"
