should = require 'should'
{Adapter, TextMessage, EnterMessage, LeaveMessage, TopicMessage, Message, CatchAllMessage} = require.main.require 'hubot'

describe 'Adapter', ->
  it 'Should initialize with a robot', ->
    @slackbot.robot.should.eql @stubs.robot

describe 'Login', ->
  it 'Should set the robot name', ->
    @slackbot.robot.name.should.equal 'bot'

describe 'Logger', ->
  it 'It should log missing token error', ->
    {logger} = @slackbot.robot
    @slackbot.options.token = null
    @slackbot.run()
    logger.logs["error"].length.should.be.above(0)
    logger.logs["error"][logger.logs["error"].length-1].should.equal 'No service token provided to Hubot'

  it 'It should log invalid token error', ->
    {logger} = @slackbot.robot
    @slackbot.options.token = "ABC123"
    @slackbot.run() -
    logger.logs["error"].length.should.be.above(0)
    logger.logs["error"][logger.logs["error"].length-1].should.equal 'Invalid service token provided, please follow the upgrade instructions'

describe 'Send Messages', ->
  it 'Should send a message', ->
    sentMessages = @slackbot.send {room: 'general'}, 'message'
    sentMessages.length.should.equal 1
    sentMessages[0].should.equal 'message'

  it 'Should send multiple messages', ->
    sentMessages = @slackbot.send {room: 'general'}, 'one', 'two', 'three'
    sentMessages.length.should.equal 3

  it 'Should not send empty messages', ->
    sentMessages = @slackbot.send {room: 'general'}, 'Hello', '', '', 'world!'
    sentMessages.length.should.equal 2

  it 'Should open a DM channel if needed', ->
    msg = 'Test'
    @slackbot.send {room: 'name'}, msg
    @stubs._msg.should.eql 'Test'

  it 'Should use an existing DM channel if possible', ->
    msg = 'Test'
    @slackbot.send {room: 'user2'}, msg
    @stubs._dmmsg.should.eql 'Test'


describe 'Client sending message', ->
  it 'Should append as_user = true', ->
    @client.send {room: 'name'}, {text: 'foo', user: @stubs.user, channel: @stubs.channel}
    @stubs._opts.as_user.should.eql true

  it 'Should append as_user = true only as a default', ->
    @client.send {room: 'name'}, {text: 'foo', user: @stubs.user, channel: @stubs.channel, as_user: false}
    @stubs._opts.as_user.should.eql false

describe 'Reply to Messages', ->
  it 'Should mention the user in a reply sent in a channel', ->
    sentMessages = @slackbot.reply {user: @stubs.user, room: @stubs.channel.id}, 'message'
    sentMessages.length.should.equal 1
    sentMessages[0].should.equal "<@#{@stubs.user.id}>: message"

  it 'Should mention the user in multiple replies sent in a channel', ->
    sentMessages = @slackbot.reply {user: @stubs.user, room: @stubs.channel.id}, 'one', 'two', 'three'
    sentMessages.length.should.equal 3
    sentMessages[0].should.equal "<@#{@stubs.user.id}>: one"
    sentMessages[1].should.equal "<@#{@stubs.user.id}>: two"
    sentMessages[2].should.equal "<@#{@stubs.user.id}>: three"

  it 'Should send nothing if messages are empty', ->
    sentMessages = @slackbot.reply {user: @stubs.user, room: @stubs.channel.id}, ''
    sentMessages.length.should.equal 0

  it 'Should NOT mention the user in a reply sent in a DM', ->
    sentMessages = @slackbot.reply {user: @stubs.user, room: 'D123'}, 'message'
    sentMessages.length.should.equal 1
    sentMessages[0].should.equal "message"

describe 'Setting the channel topic', ->
  it 'Should set the topic in channels', ->
    @slackbot.topic {room: @stubs.channel.id}, 'channel'
    @stubs._topic.should.equal 'channel'

  it 'Should NOT set the topic in DMs', ->
    @slackbot.topic {room: 'D1232'}, 'DM'
    should.not.exists(@stubs._topic)

describe 'Receiving an error event', ->
  it 'Should propogate that error', ->
    @hit = false
    @slackbot.robot.on 'error', (error) =>
      error.msg.should.equal 'ohno'
      @hit = true
    @hit.should.equal false
    @slackbot.error {msg: 'ohno', code: -2}
    @hit.should.equal true

describe 'Handling incoming messages', ->
  it 'Should handle regular messages as hoped and dreamed', ->
    @slackbot.message {text: 'foo', user: @stubs.user, channel: @stubs.channel}
    @stubs._received.text.should.equal 'foo'

  it 'Should prepend our name to a message addressed to us in a DM', ->
    @slackbot.message {text: 'foo', user: @stubs.user, channel: @stubs.DM}
    @stubs._received.text.should.equal "#{@slackbot.robot.name} foo"

  it 'Should handle channel_join events as envisioned', ->
    @slackbot.message {subtype: 'channel_join', user: @stubs.user, channel: @stubs.channel}
    should.equal (@stubs._received instanceof EnterMessage), true
    @stubs._received.user.id.should.equal @stubs.user.id

  it 'Should handle channel_leave events as envisioned', ->
    @slackbot.message {subtype: 'channel_leave', user: @stubs.user, channel: @stubs.channel}
    should.equal (@stubs._received instanceof LeaveMessage), true
    @stubs._received.user.id.should.equal @stubs.user.id

  it 'Should handle channel_topic events as envisioned', ->
    @slackbot.message {subtype: 'channel_topic', user: @stubs.user, channel: @stubs.channel}
    should.equal (@stubs._received instanceof TopicMessage), true
    @stubs._received.user.id.should.equal @stubs.user.id

  it 'Should handle group_join events as envisioned', ->
    @slackbot.message {subtype: 'group_join', user: @stubs.user, channel: @stubs.channel}
    should.equal (@stubs._received instanceof EnterMessage), true
    @stubs._received.user.id.should.equal @stubs.user.id

  it 'Should handle group_leave events as envisioned', ->
    @slackbot.message {subtype: 'group_leave', user: @stubs.user, channel: @stubs.channel}
    should.equal (@stubs._received instanceof LeaveMessage), true
    @stubs._received.user.id.should.equal @stubs.user.id

  it 'Should handle group_topic events as envisioned', ->
    @slackbot.message {subtype: 'group_topic', user: @stubs.user, channel: @stubs.channel}
    should.equal (@stubs._received instanceof TopicMessage), true
    @stubs._received.user.id.should.equal @stubs.user.id

  it 'Should handle unknown events as catchalls', ->
    @slackbot.message {subtype: 'hidey_ho', user: @stubs.user, channel: @stubs.channel}
    should.equal (@stubs._received instanceof CatchAllMessage), true

  it 'Should not crash with bot messages', ->
    @slackbot.message { subtype: 'bot_message', bot: @stubs.bot, channel: @stubs.channel, text: 'Pushing is the answer' }
    should.equal (@stubs._received instanceof TextMessage), true

  it 'Should ignore messages it sent itself', ->
    @slackbot.message { subtype: 'bot_message', user: @stubs.self, channel: @stubs.channel, text: 'Ignore me' }
    should.equal @stubs._received, undefined

  it 'Should ignore messages it sent itself, if sent as a botuser', ->
    @slackbot.message { subtype: 'bot_message', bot: @stubs.self_bot, channel: @stubs.channel, text: 'Ignore me' }
    should.equal @stubs._received, undefined
