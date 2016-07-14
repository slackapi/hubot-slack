should = require 'should'

describe 'Adapter', ->
  it 'Should initialize with a robot', ->
    @slackbot.robot.should.eql @stubs.robot

describe 'Login', ->
  it 'Should set the robot name', ->
    @slackbot.robot.name.should.equal 'bot'

describe 'Send Messages', ->
  it 'Should send a message', ->
    sentMessage = @slackbot.send {room: 'general'}, 'message'
    @stubs._msg.should.equal 'message'

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

describe 'User change', ->
  it 'Should add new user', ->
    @slackbot.user_change { user: @stubs.user }
    @stubs.robot.brain.data.users[@stubs.user.id].should.eql {
      id: @stubs.user.id
      name: @stubs.user.name
      real_name: @stubs.user.real_name
      email_address: @stubs.user.profile.email
      slack: @stubs.user
    }
  it 'Should reload user', ->
    @stubs.robot.brain.userForId @stubs.user.id, {
      id: @stubs.user.id
      name: 'test'
      real_name: @stubs.user.real_name
      email_address: @stubs.user.profile.email
      slack: @stubs.user
    }
    @slackbot.user_change { user: @stubs.user }
    @stubs.robot.brain.data.users[@stubs.user.id].should.eql {
      id: @stubs.user.id
      name: @stubs.user.name
      real_name: @stubs.user.real_name
      email_address: @stubs.user.profile.email
      slack: @stubs.user
    }

describe 'Brain Loaded', ->
  it 'Should reload all users', ->
    @slackbot.brain_loaded()
    @stubs.robot.brain.data.users[@stubs.user.id].should.eql {
      id: @stubs.user.id
      name: @stubs.user.name
      real_name: @stubs.user.real_name
      email_address: @stubs.user.profile.email
      slack: @stubs.user
    }
    @stubs.robot.brain.data.users[@stubs.self.id].should.eql {
      id: @stubs.self.id
      name: @stubs.self.name
      real_name: @stubs.self.real_name
      email_address: @stubs.self.profile.email
      slack: @stubs.self
    }

  it 'Should wipe out broken users', ->
    @stubs.robot.brain.userForId @stubs.user.name, {
      id: @stubs.user.id
      name: @stubs.user.name
      real_name: @stubs.user.real_name
      email_address: @stubs.user.profile.email
      slack: @stubs.user
    }
    @slackbot.brain_loaded()
    @stubs.robot.brain.data.users.hasOwnProperty(@stubs.user.name).should.eql false