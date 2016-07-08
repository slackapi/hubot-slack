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

  it 'Should initialize with an empty listern', ->
    @client.listeners.length.should.equal 0

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