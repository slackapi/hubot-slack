should = require 'should'
chai = require 'chai'
mockery = require 'mockery'
hubotSlackMock = require '../slack.coffee'
mockery.registerMock('hubot-slack', hubotSlackMock);

{ EnterMessage, LeaveMessage, TopicMessage, CatchAllMessage, Robot, loadBot } = require.main.require 'hubot'
{ SlackTextMessage, ReactionMessage, PresenceMessage, FileSharedMessage } = require '../src/message'
SlackClient = require '../src/client'
_ = require 'lodash'

describe 'Adapter', ->
  before ->
    mockery.enable({
      warnOnUnregistered: false
    });
  
  after ->
    mockery.disable()
  
  it 'Should initialize with a robot', ->
    @slackbot.robot.should.eql @stubs.robot

  it 'Should load an instance of Robot with extended methods', ->
    loadedRobot = loadBot('', 'slack', false, 'Hubot')
    
    # Check to make sure presenceChange and react are loaded to Robot
    loadedRobot.presenceChange.should.be.an.instanceOf(Function).with.lengthOf(3)
    loadedRobot.react.should.be.an.instanceOf(Function).with.lengthOf(3)
    loadedRobot.fileShared.should.be.an.instanceOf(Function).with.lengthOf(3)

describe 'Connect', ->
  it 'Should connect successfully', ->
    @slackbot.run()
    @stubs._connected.should.be.true

describe 'Authenticate', ->
  it 'Should authenticate successfully', ->
    {logger} = @slackbot.robot
    start = self: {
      id: @stubs.self.id
      name: @stubs.self.name
    },
    team: {
      id: @stubs.team.id,
      name: @stubs.team.name
    },
    users: [
      @stubs.self,
      @stubs.user
    ]

    @slackbot.authenticated start
    @slackbot.self.id.should.equal @stubs.self.id
    @slackbot.robot.name.should.equal @stubs.self.name
    logger.logs["info"].length.should.be.above(0)
    logger.logs["info"][logger.logs["info"].length-1].should.equal "Logged in as @#{@stubs.self.name} in workspace #{@stubs.team.name}"

describe 'Logger', ->
  it 'It should log missing token error', ->
    {logger} = @slackbot.robot
    @slackbot.options.token = null
    @slackbot.run()
    logger.logs["error"].length.should.be.above(0)
    logger.logs["error"][logger.logs["error"].length-1].should.equal 'No token provided to Hubot'

  it 'It should log invalid token error', ->
    {logger} = @slackbot.robot
    @slackbot.options.token = "ABC123"
    @slackbot.run() -
    logger.logs["error"].length.should.be.above(0)
    logger.logs["error"][logger.logs["error"].length-1].should.equal 'Invalid token provided, please follow the upgrade instructions'

describe 'Disable Sync', ->
  it 'Should sync users by default', ->
    @slackbot.run()
    @slackbot.robot.brain.data.users.should.have.keys('1','2','3','4')

  it 'Should not sync users when disabled', ->
    @slackbot.options.disableUserSync = true
    @slackbot.run()
    @slackbot.robot.brain.data.users.should.be.empty()

  # Test moved to fetchUsers() in client.coffee because of change in code logic
  #it 'Should still sync interacting users when disabled'

describe 'Send Messages', ->

  it 'Should send a message', ->
    @slackbot.send {room: @stubs.channel.id}, 'message'
    @stubs._sendCount.should.equal 1
    @stubs._msg.should.equal 'message'

  it 'Should send multiple messages', ->
    @slackbot.send {room: @stubs.channel.id}, 'one', 'two', 'three'
    @stubs._sendCount.should.equal 3

  it 'Should not send empty messages', ->
    @slackbot.send {room: @stubs.channel.id}, 'Hello', '', '', 'world!'
    @stubs._sendCount.should.equal 2

  it 'Should not fail for inexistant user', ->
    chai.expect(() => @slackbot.send {room: 'U987'}, 'Hello').to.not.throw()

  it 'Should open a DM channel if needed', ->
    msg = 'Test'
    @slackbot.send {room: @stubs.user.id}, msg
    @stubs._dmmsg.should.eql msg

  it 'Should send a message to a user', ->
    @slackbot.send @stubs.user, 'message'
    @stubs._dmmsg.should.eql 'message'
    @stubs._room.should.eql @stubs.user.id


describe 'Client sending message', ->
  it 'Should append as_user = true', ->
    @client.send {room: @stubs.channel.id}, {text: 'foo', user: @stubs.user, channel: @stubs.channel.id}
    @stubs._opts.as_user.should.eql true

  it 'Should append as_user = true only as a default', ->
    @client.send {room: @stubs.channel.id}, {text: 'foo', user: @stubs.user, channel: @stubs.channel.id, as_user: false}
    @stubs._opts.as_user.should.eql false

describe 'Reply to Messages', ->
  it 'Should mention the user in a reply sent in a channel', ->
    @slackbot.reply {user: @stubs.user, room: @stubs.channel.id}, 'message'
    @stubs._sendCount.should.equal 1
    @stubs._msg.should.equal "<@#{@stubs.user.id}>: message"

  it 'Should mention the user in multiple replies sent in a channel', ->
    @slackbot.reply {user: @stubs.user, room: @stubs.channel.id}, 'one', 'two', 'three'
    @stubs._sendCount.should.equal 3
    @stubs._msg.should.equal "<@#{@stubs.user.id}>: three"

  it 'Should send nothing if messages are empty', ->
    @slackbot.reply {user: @stubs.user, room: @stubs.channel.id}, ''
    @stubs._sendCount.should.equal 0

  it 'Should NOT mention the user in a reply sent in a DM', ->
    @slackbot.reply {user: @stubs.user, room: @stubs.DM.id }, 'message'
    @stubs._sendCount.should.equal 1
    @stubs._dmmsg.should.equal "message"

describe 'Setting the channel topic', ->

  it 'Should set the topic in channels', (done) ->
    @stubs.receiveMock.onTopic = (topic) ->
      topic.should.equal 'channel'
      done()
    @slackbot.setTopic {room: @stubs.channel.id}, 'channel'
    return

  it 'Should NOT set the topic in DMs', ->
    @slackbot.setTopic {room: 'D1232'}, 'DM'
    should.not.exists(@stubs._topic)

describe 'Receiving an error event', ->
  it 'Should propagate that error', ->
    @hit = false
    @slackbot.robot.on 'error', (error) =>
      error.msg.should.equal 'ohno'
      @hit = true
    @hit.should.equal false
    @slackbot.error {msg: 'ohno', code: -2}
    @hit.should.equal true

  it 'Should handle rate limit errors', ->
    {logger} = @slackbot.robot
    @slackbot.error {msg: 'ratelimit', code: -1}
    logger.logs["error"].length.should.be.above(0)

describe 'Handling incoming messages', ->

  it 'Should handle regular messages as hoped and dreamed', (done) ->
    @stubs.receiveMock.onReceived = (msg) ->
      msg.text.should.equal 'foo'
      done()
    @slackbot.eventHandler {type: 'message', text: 'foo', user: @stubs.user, channel: @stubs.channel.id }
    return

  it 'Should prepend our name to a name-lacking message addressed to us in a DM', ->
    bot_name = @slackbot.robot.name
    @stubs.receiveMock.onReceived = (msg) ->
      msg.text.should.equal "#{bot_name} foo"
      done()
    @slackbot.eventHandler {type: 'message', text: "foo", user: @stubs.user, channel: @stubs.DM.id}
    return

  it 'Should NOT prepend our name to a name-containing message addressed to us in a DM', ->
    bot_name = @slackbot.robot.name
    @stubs.receiveMock.onReceived = (msg) ->
      msg.text.should.equal "#{bot_name} foo"
      done()
    @slackbot.eventHandler {type: 'message', text: "#{bot_name} foo", user: @stubs.user, channel: @stubs.DM.id}
    return

  it 'Should return a message object with raw text and message', (done) ->
    #the shape of this data is an RTM message event passed through SlackClient#messageWrapper
    #see: https://api.slack.com/events/message
    messageData = {
      type: 'message'
      user: @stubs.user,
      channel: @stubs.channel.id,
      text: 'foo <http://www.example.com> bar',
    }
    @stubs.receiveMock.onReceived = (msg) ->
      should.equal (msg instanceof SlackTextMessage), true
      should.equal msg.text, "foo http://www.example.com bar"
      should.equal msg.rawText, "foo <http://www.example.com> bar"
      should.equal msg.rawMessage, messageData
      done()
    @slackbot.eventHandler messageData
    return

  it 'Should handle member_joined_channel events as envisioned', ->
    @slackbot.eventHandler {type: 'member_joined_channel', user: @stubs.user, channel: @stubs.channel.id}
    should.equal @stubs._received.constructor.name, "EnterMessage"
    @stubs._received.user.id.should.equal @stubs.user.id

  it 'Should handle member_left_channel events as envisioned', ->
    @slackbot.eventHandler {type: 'member_left_channel', user: @stubs.user, channel: @stubs.channel.id}
    should.equal @stubs._received.constructor.name, "LeaveMessage"
    @stubs._received.user.id.should.equal @stubs.user.id

  it 'Should handle channel_topic events as envisioned', ->
    @slackbot.eventHandler {type: 'message', subtype: 'channel_topic', user: @stubs.user, channel: @stubs.channel.id}
    should.equal @stubs._received.constructor.name, "TopicMessage"
    @stubs._received.user.id.should.equal @stubs.user.id

  it 'Should handle group_topic events as envisioned', ->
    @slackbot.eventHandler {type: 'message', subtype: 'group_topic', user: @stubs.user, channel: @stubs.channel.id}
    should.equal @stubs._received.constructor.name, "TopicMessage"
    @stubs._received.user.id.should.equal @stubs.user.id

  it 'Should handle reaction_added events as envisioned', ->
    reactionMessage = {
      type: 'reaction_added', user: @stubs.user, item_user: @stubs.self
      item: { type: 'message', channel: @stubs.channel.id, ts: '1360782804.083113'
      },
      reaction: 'thumbsup', event_ts: '1360782804.083113'
    }
    @slackbot.eventHandler reactionMessage
    should.equal (@stubs._received instanceof ReactionMessage), true
    should.equal @stubs._received.user.id, @stubs.user.id
    should.equal @stubs._received.user.room, @stubs.channel.id
    should.equal @stubs._received.item_user.id, @stubs.self.id
    should.equal @stubs._received.type, 'added'
    should.equal @stubs._received.reaction, 'thumbsup'

  it 'Should handle reaction_removed events as envisioned', ->
    reactionMessage = {
      type: 'reaction_removed', user: @stubs.user, item_user: @stubs.self
      item: { type: 'message', channel: @stubs.channel.id, ts: '1360782804.083113'
      },
      reaction: 'thumbsup', event_ts: '1360782804.083113'
    }
    @slackbot.eventHandler reactionMessage
    should.equal (@stubs._received instanceof ReactionMessage), true
    should.equal @stubs._received.user.id, @stubs.user.id
    should.equal @stubs._received.user.room, @stubs.channel.id
    should.equal @stubs._received.item_user.id, @stubs.self.id
    should.equal @stubs._received.type, 'removed'
    should.equal @stubs._received.reaction, 'thumbsup'

  it 'Should not crash with bot messages', (done) ->
    @stubs.receiveMock.onReceived = (msg) ->
      should.equal (msg instanceof SlackTextMessage), true
      done()
    @slackbot.eventHandler {type: 'message', subtype: 'bot_message', user: @stubs.user, channel: @stubs.channel.id, text: 'Pushing is the answer', returnRawText: true }
    return

  it 'Should handle single user presence_change events as envisioned', ->
    @slackbot.robot.brain.userForId(@stubs.user.id, @stubs.user)
    presenceMessage = {
      type: 'presence_change', user: @stubs.user, presence: 'away'
    }
    @slackbot.eventHandler presenceMessage
    should.equal (@stubs._received instanceof PresenceMessage), true
    should.equal @stubs._received.users[0].id, @stubs.user.id
    @stubs._received.users.length.should.equal 1

  it 'Should handle presence_change events as envisioned', ->
    @slackbot.robot.brain.userForId(@stubs.user.id, @stubs.user)
    presenceMessage = {
      type: 'presence_change', users: [@stubs.user.id], presence: 'away'
    }
    @slackbot.eventHandler presenceMessage
    should.equal (@stubs._received instanceof PresenceMessage), true
    should.equal @stubs._received.users[0].id, @stubs.user.id
    @stubs._received.users.length.should.equal 1

  it 'Should ignore messages it sent itself', ->
    @slackbot.eventHandler {type: 'message', subtype: 'bot_message', user: @stubs.self, channel: @stubs.channel.id, text: 'Ignore me' }
    should.equal @stubs._received, undefined

  it 'Should ignore reaction events that it generated itself', ->
    reactionMessage = { type: 'reaction_removed', user: @stubs.self, reaction: 'thumbsup', event_ts: '1360782804.083113' }
    @slackbot.eventHandler reactionMessage
    should.equal @stubs._received, undefined

  it 'Should handle empty users as envisioned', (done)->
    @stubs.receiveMock.onReceived = (msg) ->
      should.equal (msg instanceof SlackTextMessage), true
      done()
    @slackbot.eventHandler {type: 'message', subtype: 'bot_message', user: {}, channel: @stubs.channel.id, text: 'Foo'}
    return

  it 'Should handle reaction events from users who are in different workspace in shared channel', ->
    reactionMessage = {
      type: 'reaction_added', user: @stubs.org_user_not_in_workspace_in_channel, item_user: @stubs.self
      item: { type: 'message', channel: @stubs.channel.id, ts: '1360782804.083113'
      },
      reaction: 'thumbsup', event_ts: '1360782804.083113'
    }

    @slackbot.eventHandler reactionMessage
    should.equal (@stubs._received instanceof ReactionMessage), true
    should.equal @stubs._received.user.id, @stubs.org_user_not_in_workspace_in_channel.id
    should.equal @stubs._received.user.room, @stubs.channel.id
    should.equal @stubs._received.item_user.id, @stubs.self.id
    should.equal @stubs._received.type, 'added'
    should.equal @stubs._received.reaction, 'thumbsup'
    
  it 'Should handle file_shared events as envisioned', ->
    fileMessage = {
      type: 'file_shared', user: @stubs.user,
      file_id: 'F2147483862', event_ts: '1360782804.083113'
    }
    @slackbot.eventHandler fileMessage
    should.equal (@stubs._received instanceof FileSharedMessage), true
    should.equal @stubs._received.user.id, @stubs.user.id
    should.equal @stubs._received.file_id, 'F2147483862'

describe 'Robot.react DEPRECATED', ->
  before ->
    user = { id: @stubs.user.id, room: @stubs.channel.id }
    item = {
      type: 'message', channel: @stubs.channel.id, ts: '1360782804.083113'
    }
    @reactionMessage = new ReactionMessage(
      'reaction_added', user, 'thumbsup', item, '1360782804.083113'
    )
    @handleReaction = (msg) -> "#{msg.reaction} handled"

  it 'Should register a Listener with callback only', ->
    @slackbot.robot.react @handleReaction
    listener = @slackbot.robot.listeners.shift()
    listener.matcher(@reactionMessage).should.be.true
    listener.options.should.eql({id: null})
    listener.callback(@reactionMessage).should.eql('thumbsup handled')

  it 'Should register a Listener with opts and callback', ->
    @slackbot.robot.react {id: 'foobar'}, @handleReaction
    listener = @slackbot.robot.listeners.shift()
    listener.matcher(@reactionMessage).should.be.true
    listener.options.should.eql({id: 'foobar'})
    listener.callback(@reactionMessage).should.eql('thumbsup handled')

  it 'Should register a Listener with matcher and callback', ->
    matcher = (msg) -> msg.type == 'added'
    @slackbot.robot.react matcher, @handleReaction
    listener = @slackbot.robot.listeners.shift()
    listener.matcher(@reactionMessage).should.be.true
    listener.options.should.eql({id: null})
    listener.callback(@reactionMessage).should.eql('thumbsup handled')

  it 'Should register a Listener with matcher, opts, and callback', ->
    matcher = (msg) -> msg.type == 'removed' || msg.reaction == 'thumbsup'
    @slackbot.robot.react matcher, {id: 'foobar'}, @handleReaction
    listener = @slackbot.robot.listeners.shift()
    listener.matcher(@reactionMessage).should.be.true
    listener.options.should.eql({id: 'foobar'})
    listener.callback(@reactionMessage).should.eql('thumbsup handled')

  it 'Should register a Listener that does not match the ReactionMessage', ->
    matcher = (msg) -> msg.type == 'removed'
    @slackbot.robot.react matcher, @handleReaction
    listener = @slackbot.robot.listeners.shift()
    listener.matcher(@reactionMessage).should.be.false
    
describe 'Robot.fileShared', ->
  before -> 
    user = { id: @stubs.user.id, room: @stubs.channel.id }
    @fileSharedMessage = new FileSharedMessage(user, "F2147483862", '1360782804.083113')
    @handleFileShared = (msg) -> "#{msg.file_id} shared"

  it 'Should register a Listener with callback only', ->
    @slackbot.robot.fileShared @handleFileShared
    listener = @slackbot.robot.listeners.shift()
    listener.matcher(@fileSharedMessage).should.be.true
    listener.options.should.eql({id: null})
    listener.callback(@fileSharedMessage).should.eql('F2147483862 shared')
    
  it 'Should register a Listener with opts and callback', ->
    @slackbot.robot.fileShared {id: 'foobar'}, @handleFileShared
    listener = @slackbot.robot.listeners.shift()
    listener.matcher(@fileSharedMessage).should.be.true
    listener.options.should.eql({id: 'foobar'})
    listener.callback(@fileSharedMessage).should.eql('F2147483862 shared')

  it 'Should register a Listener with matcher and callback', ->
    matcher = (msg) -> msg.file_id == 'F2147483862'
    @slackbot.robot.fileShared matcher, @handleFileShared
    listener = @slackbot.robot.listeners.shift()
    listener.matcher(@fileSharedMessage).should.be.true
    listener.options.should.eql({id: null})
    listener.callback(@fileSharedMessage).should.eql('F2147483862 shared')

  it 'Should register a Listener with matcher, opts, and callback', ->
    matcher = (msg) -> msg.file_id == 'F2147483862'
    @slackbot.robot.fileShared matcher, {id: 'foobar'}, @handleFileShared
    listener = @slackbot.robot.listeners.shift()
    listener.matcher(@fileSharedMessage).should.be.true
    listener.options.should.eql({id: 'foobar'})
    listener.callback(@fileSharedMessage).should.eql('F2147483862 shared')

  it 'Should register a Listener that does not match the ReactionMessage', ->
    matcher = (msg) -> msg.file_id == 'J12387ALDFK'
    @slackbot.robot.fileShared matcher, @handleFileShared
    listener = @slackbot.robot.listeners.shift()
    listener.matcher(@fileSharedMessage).should.be.false

describe 'Robot.hearReaction', ->
  before ->
    user = { id: @stubs.user.id, room: @stubs.channel.id }
    item = {
      type: 'message', channel: @stubs.channel.id, ts: '1360782804.083113'
    }
    @reactionMessage = new ReactionMessage(
      'reaction_added', user, 'thumbsup', item, '1360782804.083113'
    )
    @handleReaction = (msg) -> "#{msg.reaction} handled"

  it 'Should register a Listener with callback only', ->
    @slackbot.robot.hearReaction @handleReaction
    listener = @slackbot.robot.listeners.shift()
    listener.matcher(@reactionMessage).should.be.true
    listener.options.should.eql({id: null})
    listener.callback(@reactionMessage).should.eql('thumbsup handled')

  it 'Should register a Listener with opts and callback', ->
    @slackbot.robot.hearReaction {id: 'foobar'}, @handleReaction
    listener = @slackbot.robot.listeners.shift()
    listener.matcher(@reactionMessage).should.be.true
    listener.options.should.eql({id: 'foobar'})
    listener.callback(@reactionMessage).should.eql('thumbsup handled')

  it 'Should register a Listener with matcher and callback', ->
    matcher = (msg) -> msg.type == 'added'
    @slackbot.robot.hearReaction matcher, @handleReaction
    listener = @slackbot.robot.listeners.shift()
    listener.matcher(@reactionMessage).should.be.true
    listener.options.should.eql({id: null})
    listener.callback(@reactionMessage).should.eql('thumbsup handled')

  it 'Should register a Listener with matcher, opts, and callback', ->
    matcher = (msg) -> msg.type == 'removed' || msg.reaction == 'thumbsup'
    @slackbot.robot.hearReaction matcher, {id: 'foobar'}, @handleReaction
    listener = @slackbot.robot.listeners.shift()
    listener.matcher(@reactionMessage).should.be.true
    listener.options.should.eql({id: 'foobar'})
    listener.callback(@reactionMessage).should.eql('thumbsup handled')

  it 'Should register a Listener that does not match the ReactionMessage', ->
    matcher = (msg) -> msg.type == 'removed'
    @slackbot.robot.hearReaction matcher, @handleReaction
    listener = @slackbot.robot.listeners.shift()
    listener.matcher(@reactionMessage).should.be.false

describe 'Users data', ->
  it 'Should load users data from web api', ->
    @slackbot.usersLoaded(null, @stubs.responseUsersList)

    user = @slackbot.robot.brain.data.users[@stubs.user.id]
    should.equal user.id, @stubs.user.id
    should.equal user.name, @stubs.user.name
    should.equal user.real_name, @stubs.user.real_name
    should.equal user.email_address, @stubs.user.profile.email
    should.equal user.slack.misc, @stubs.user.misc

    userperiod = @slackbot.robot.brain.data.users[@stubs.userperiod.id]
    should.equal userperiod.id, @stubs.userperiod.id
    should.equal userperiod.name, @stubs.userperiod.name
    should.equal userperiod.real_name, @stubs.userperiod.real_name
    should.equal userperiod.email_address, @stubs.userperiod.profile.email

  it 'Should merge with user data which is stored by other program', ->
    originalUser =
      something: 'something'

    @slackbot.robot.brain.userForId @stubs.user.id, originalUser
    @slackbot.usersLoaded(null, @stubs.responseUsersList)

    user = @slackbot.robot.brain.data.users[@stubs.user.id]
    should.equal user.id, @stubs.user.id
    should.equal user.name, @stubs.user.name
    should.equal user.real_name, @stubs.user.real_name
    should.equal user.email_address, @stubs.user.profile.email
    should.equal user.slack.misc, @stubs.user.misc
    should.equal user.something, originalUser.something

  it 'Should detect wrong response from web api', ->
    @slackbot.usersLoaded(null, @stubs.wrongResponseUsersList)
    should.equal @slackbot.robot.brain.data.users[@stubs.user.id], undefined
