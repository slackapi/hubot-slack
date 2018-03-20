{RtmClient, WebClient, MemoryDataStore} = require '@slack/client'
SlackFormatter = require '../src/formatter'
should = require 'should'
_ = require 'lodash'

describe 'Init', ->
  it 'Should initialize with an RTM client', ->
    (@client.rtm instanceof RtmClient).should.equal true
    @client.rtm._token.should.equal 'xoxb-faketoken'

  it 'Should initialize with a Web client', ->
    (@client.web instanceof WebClient).should.equal true
    @client.web._token.should.equal 'xoxb-faketoken'

  it 'Should initialize with a SlackFormatter - DEPRECATED', ->
    (@client.format instanceof SlackFormatter).should.equal true

describe 'connect()', ->
  it 'Should be able to connect', ->
    @client.connect();
    @stubs._connected.should.be.true

# describe 'onMessage()', ->
#   it 'should not need to be set', ->
#     @client.rtm.emit('message', { fake: 'message' })
#     (true).should.be.ok
#   it 'should emit pre-processed messages to the callback', (done) ->
#     @client.onMessage (message) =>
#       message.should.be.ok
#       message.user.real_name.should.equal @stubs.user.real_name
#       message.channel.name.should.equal @stubs.channel.name
#       done()
#     # the shape of the following object is a raw RTM message event: https://api.slack.com/events/message
#     @client.rtm.emit('message', {
#       type: 'message',
#       user: @stubs.user.id,
#       channel: @stubs.channel.id,
#       text: 'blah',
#       ts: '1355517523.000005'
#     })
#     # NOTE: the following check does not appear to work as expected
#     setTimeout(( =>
#       @stubs.robot.logger.logs.should.not.have.property('error')
#     ), 0);
#   it 'should log an error when expanded info cannot be fetched using the Web API', (done) ->
#     # NOTE: to be certain nothing goes wrong in the rejection handling, the "unhandledRejection" / "rejectionHandled"
#     # global events need to be instrumented
#     @client.onMessage (message) ->
#       done(new Error('A message was emitted'))
#     @client.rtm.emit('message', {
#       type: 'message',
#       user: 'NOT A USER',
#       channel:  @stubs.channel.id,
#       text: 'blah',
#       ts: '1355517523.000005'
#     })
#     setTimeout(( =>
#       @stubs.robot.logger.logs?.error.length.should.equal 1
#       done()
#     ), 0);

describe 'on() - DEPRECATED', ->
  it 'Should register events on the RTM stream', ->
    event = undefined
    @client.on 'some_event', (e) -> event = e
    @client.rtm.emit('some_event', {})
    event.should.be.ok

describe 'disconnect()', ->
  it 'Should disconnect RTM', ->
    @client.disconnect()
    @stubs._connected.should.be.false
  it 'should remove all RTM listeners - LEGACY', ->
    @client.on 'some_event', _.noop
    @client.disconnect()
    @client.rtm.listeners('some_event', true).should.not.be.ok

describe 'setTopic()', ->
  it "Should set the topic in a channel", (done) ->
    @client.setTopic @stubs.channel.id, 'iAmTopic'
    setTimeout(() =>
      @stubs._topic.should.equal 'iAmTopic'
      done()
    , 0)
  it "should not set the topic in a DM", (done) ->
    @client.setTopic @stubs.DM.id, 'iAmTopic'
    setTimeout(() =>
      @stubs.should.not.have.property('_topic')
      # NOTE: no good way to assert that debug log was output
      done()
    , 0)
  it "should log an error if the setTopic web API method fails", (done) ->
    @client.setTopic 'NOT A CONVERSATION', 'iAmTopic'
    setTimeout(() =>
      @stubs.should.not.have.property('_topic')
      @stubs.robot.logger.logs?.error.length.should.equal 1
      done()
    , 0)

describe 'send()', ->
  it 'Should send a plain string message to room', ->
    @client.send {room: 'room1'}, 'Message'
    @stubs._msg.should.equal 'Message'
    @stubs._room.should.equal 'room1'

  it 'Should send an object message to room', ->
    @client.send {room: 'room2'}, {text: 'textMessage'}
    @stubs._msg.should.equal 'textMessage'
    @stubs._room.should.equal 'room2'

  it 'Should be able to send a DM to a user object', ->
    @client.send @stubs.user, 'DM Message'
    @stubs._dmmsg.should.equal 'DM Message'
    @stubs._room.should.equal @stubs.user.id

describe 'loadUsers()', ->
  it 'should make successive calls to users.list', ->
    @client.loadUsers (err, result) =>
      @stubs?._listCount.should.equal 2
      result.members.length.should.equal 3
  it 'should handle errors', ->
    @stubs._listError = true
    @client.loadUsers (err, result) =>
      err.should.be.an.Error
