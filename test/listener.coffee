{SlackRawMessage, SlackBotMessage, SlackTextMessage} = require '../src/message'
{SlackBotListener, SlackRawListener} = require '../src/listener'
should = require 'should'


describe 'Listeners', ->

  it 'Should fail on incorrect message type', ->
    callback = (response) ->
    matcher = (message) -> message.text.match /Hello/
    
    listener = new SlackRawListener(@stubs.robot, matcher, callback)    
    listener.call().should.be.false


  it 'Should call a SlackRawListener', ->
    callback = (response) ->
    matcher = (message) -> message.text.match /Hello/
    
    message = new SlackRawMessage(@stubs.user.id, 'Hello world', 'Hello world', {ts: 1234})
    listener = new SlackRawListener(@stubs.robot, matcher, callback)    
    listener.call(message).should.be.true


  it 'Should call a SlackBotListener', ->
    callback = (response) ->
    message = new SlackBotMessage(@stubs.user.id, 'Hello world', 'Hello world', {ts: 1234})
    listener = new SlackBotListener(@stubs.robot, /Hello/, callback)    
    listener.call(message).should.be.true
