{RtmClient, WebClient, MemoryDataStore} = require '@slack/client'
SlackFormatter = require '../src/formatter'
should = require 'should'

describe 'Init', ->
  it 'Should initialize with a rtm connection', ->
    (@client.rtm instanceof RtmClient).should.equal true
    @client.rtm._token.should.equal 'xoxb-faketoken'

  it 'Should initialize with a web connection', ->
    (@client.web instanceof WebClient).should.equal true
    @client.web._token.should.equal 'xoxb-faketoken'

  it 'Should initialize with a SlackFormatter', ->
    (@client.format instanceof SlackFormatter).should.equal true

  it 'Should initialize with an empty listener', ->
    @client.listeners.length.should.equal 0

describe 'connect()', ->
  it 'Should be able to connect', ->
    @client.connect();
    @stubs._connected.should.equal true

describe 'on()', ->
  it 'Should open with a new connection', ->
    @client.on('test', @stubs.callback)
    @client.listeners.length.should.equal 1

  it 'Should open with a new message connection', ->
    @client.on('message', @stubs.callback)
    @client.listeners.length.should.equal 1

describe 'disconnect()', ->
  it 'Should disconnect all connections', ->
    @client.on('test', @stubs.callback)
    @client.listeners.length.should.equal 1
    @client.disconnect()
    @client.listeners.length.should.equal 0

describe 'setTopic()', ->
  it "Should set the topic", ->
    @client.setTopic 12, 'iAmTopic'
    @stubs._topic.should.equal 'iAmTopic'

describe 'send()', ->
  it 'Should send a plain string message to room', ->
    @client.send {room: 'room1'}, 'Message'
    @stubs._msg.should.equal 'Message'
    @stubs._room.should.equal 'room1'

  it 'Should send an object message to room', ->
    @client.send {room: 'room2'}, {text: 'textMessage'}
    @stubs._msg.should.equal 'textMessage'
    @stubs._room.should.equal 'room2'

  it 'Should send an object message to room', ->
    @client.send {room: 'room3'}, '<test|test>'
    @stubs._msg.should.equal '<test|test>'
    @stubs._room.should.equal 'room3'