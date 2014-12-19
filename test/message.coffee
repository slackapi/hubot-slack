{SlackTextMessage, SlackRawMessage, SlackBotMessage, SlackRawListener, SlackBotListener} = require '../index'

should = require 'should'

class ClientMessage
  ts = 0
  constructor: (fields = {}) ->
    @type = 'message'
    @ts = (ts++).toString()
    @[k] = val for own k, val of fields

  getBody: ->
    # match what slack-client.Message does
    text = ""
    text += @text if @text
    if @attachments
      text += "\n" if @text
      for k, attach of @attachments
        text += "\n" if k > 0
        text += attach.fallback
    text

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
    @stubs.robot.received.should.have.length 1
    msg = @stubs.robot.received[0]
    msg.should.be.an.instanceOf SlackTextMessage
    msg.text.should.equal "Hello world"

  it 'should parse the text in the SlackTextMessage', ->
    @slackbot.message @makeMessage {
      user: @stubs.user.id
      text: "Foo <@U123> bar <http://slack.com>"
    }
    @stubs.robot.received.should.have.length 1
    msg = @stubs.robot.received[0]
    msg.should.be.an.instanceOf SlackTextMessage
    msg.text.should.equal "Foo @name bar http://slack.com"
    msg.rawText.should.equal "Foo <@U123> bar <http://slack.com>"

  it 'should include attachments in the SlackTextMessage text', ->
    @slackbot.message @makeMessage {
      user: @stubs.user.id
      text: "Hello world"
      attachments: [
        { fallback: "attachment fallback" }
        { fallback: "second attachment fallback" }
      ]
    }
    @stubs.robot.received.should.have.length 1
    msg = @stubs.robot.received[0]
    msg.should.be.an.instanceOf SlackTextMessage
    msg.text.should.equal "Hello world\nattachment fallback\nsecond attachment fallback"

  it 'should save the raw message in the SlackTextMessage', ->
    @slackbot.message rawMsg = @makeMessage {
      subtype: 'file_share'
      user: @stubs.user.id
      text: "Hello world"
      file:
        name: "file.txt"
    }
    @stubs.robot.received.should.have.length 1
    msg = @stubs.robot.received[0]
    msg.should.be.an.instanceOf SlackTextMessage
    msg.rawMessage.should.equal rawMsg

  it 'should produce a SlackBotMessage when the subtype is bot_message', ->
    @slackbot.message rawMsg = @makeMessage {
      subtype: 'bot_message'
      username: 'bot'
      text: 'Hello world'
      attachments: [{
        fallback: 'attachment'
      }]
    }
    @stubs.robot.received.should.have.length 1
    msg = @stubs.robot.received[0]
    msg.should.be.an.instanceOf SlackBotMessage
    msg.text.should.equal "Hello world\nattachment"
    msg.rawMessage.should.equal rawMsg

  it 'should produce a SlackRawMessage when the user is nil', ->
    @slackbot.message rawMsg = @makeMessage {
      text: 'Hello world'
    }
    @stubs.robot.received.should.have.length 1
    msg = @stubs.robot.received[0]
    msg.should.be.an.instanceOf SlackRawMessage
    msg.text.should.equal 'Hello world'
    msg.rawMessage.should.equal rawMsg

  it 'should produce a SlackRawMessage when the message is hidden', ->
    @slackbot.message @makeMessage {
      hidden: true
      user: @stubs.user.id
      text: 'Hello world'
    }
    @stubs.robot.received.should.have.length 1
    msg = @stubs.robot.received[0]
    msg.should.be.an.instanceOf SlackRawMessage

  it 'should produce a SlackRawMessage when the message has no body', ->
    @slackbot.message @makeMessage {
      user: @stubs.user.id
    }
    @stubs.robot.received.should.have.length 1
    msg = @stubs.robot.received[0]
    msg.should.be.an.instanceOf SlackRawMessage

  it 'should produce a SlackRawMessage when the message has no channel', ->
    @slackbot.message new ClientMessage {
      type: 'message'
      user: @stubs.user.id
      text: 'Hello world'
      ts: "1234"
    }
    @stubs.robot.received.should.have.length 1
    msg = @stubs.robot.received[0]
    msg.should.be.an.instanceOf SlackRawMessage
