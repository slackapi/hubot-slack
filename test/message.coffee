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

  describe 'should handle SlackRawMessage inheritance properly when Hubot', ->
    # this is a bit of a wacky one
    # We need to muck with the require() machinery
    # To that end, we're going to save off the modules we need to tweak, so we can
    # remove the cache and reload from disk
    beforeEach ->
      mods = (require.resolve name for name in ['hubot', '../src/message'])
      @saved = []
      # ensure the modules are loaded
      require path for path in mods # ensure the modules are loaded
      @saved = (require.cache[path] for path in mods) # grab the modules
      delete require.cache[path] for path in mods # remove the modules from the require cache

    afterEach ->
      # restore the saved modules
      for mod in @saved
        require.cache[mod.filename] = mod
      delete @saved

    it 'does not export Message', ->
      delete require('hubot').Message # remove hubot.Message if it exists
      {SlackRawMessage: rawMessage} = require '../src/message'
      rawMessage::constructor.__super__.constructor.name.should.equal 'Message'

    it 'does export Message', ->
      if not require('hubot').Message
        # create a placeholder class to use here
        # We're not actually running any code from Message during the evaluation
        # of src/message.coffee so we don't need the real class.
        # note: using JavaScript escape because CoffeeScript doesn't allow shadowing otherwise
        `function Message() {}`
        require('hubot').Message = Message
      {SlackRawMessage: rawMessage} = require '../src/message'
      rawMessage::constructor.__super__.constructor.name.should.equal 'Message'
