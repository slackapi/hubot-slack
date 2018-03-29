should = require 'should'
chai = require 'chai'
{ EnterMessage, LeaveMessage, TopicMessage, CatchAllMessage, Robot } = require.main.require 'hubot'
{ SlackTextMessage, ReactionMessage } = require '../src/message'
SlackClient = require '../src/client'
_ = require 'lodash'

describe 'Adapter', ->
  it 'Should initialize with a robot', ->
    @slackbot.robot.should.eql @stubs.robot

  it 'Should add the `react` method to the hubot `Robot` prototype', ->
    Robot.prototype.react.should.be.an.instanceOf(Function).with.lengthOf(3)

    # This is a sanity check to ensure the @slackbot.robot stub is proper.
    @slackbot.robot.listen.should.be.an.instanceOf(Function).with.lengthOf(3)
    @slackbot.robot.react.should.be.an.instanceOf(Function).with.lengthOf(3)

describe 'Connect', ->
  it 'Should connect successfully', ->
    @slackbot.run()
    @stubs._connected.should.be.true

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
    # Removes undefined (or unsent) messages from sentMessages
    _.remove(sentMessages, _.isUndefined)
    sentMessages.length.should.equal 2

  it 'Should not fail for inexistant user', ->
    chai.expect(() => @slackbot.send {room: 'inexistant'}, 'Hello').to.not.throw()

  it 'Should open a DM channel if needed', ->
    msg = 'Test'
    @slackbot.send {room: 'name'}, msg
    @stubs._msg.should.eql msg

  it 'Should use an existing DM channel if possible', ->
    msg = 'Test'
    @slackbot.send {room: '@user2'}, msg
    @stubs._dmmsg.should.eql msg
    @stubs._room.should.eql '@user2'

  it 'Should send a message to a user', ->
    @slackbot.send @stubs.user, 'message'
    @stubs._dmmsg.should.eql 'message'
    @stubs._room.should.eql @stubs.user.id


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
    # Removes undefined (or unsent) messages from sentMessages
    _.remove(sentMessages, _.isUndefined)
    sentMessages.length.should.equal 0

  it 'Should NOT mention the user in a reply sent in a DM', ->
    sentMessages = @slackbot.reply {user: @stubs.user, room: 'D123'}, 'message'
    sentMessages.length.should.equal 1
    sentMessages[0].should.equal "message"

describe 'Setting the channel topic', ->

  it 'Should set the topic in channels', (done) ->
    @slackbot.setTopic {room: @stubs.channel.id}, 'channel'
    setTimeout(() =>
      @stubs._topic.should.equal 'channel'
      done()
    , 0)

  it 'Should NOT set the topic in DMs', ->
    @slackbot.setTopic {room: 'D1232'}, 'DM'
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

  it 'Should handle regular messages as hoped and dreamed', (done) ->
    @stubs.receiveMock.onReceived = (msg) ->
      msg.text.should.equal 'foo'
      done()
    @slackbot.eventHandler {type: 'message', text: 'foo', user: @stubs.user, channel: @stubs.channel }
    return

  it 'Should prepend our name to a message addressed to us in a DM', (done) ->
    bot_name = @slackbot.robot.name
    @stubs.receiveMock.onReceived = (msg) ->
      msg.text.should.equal "#{bot_name} foo"
      done()
    @slackbot.eventHandler {type: 'message', text: 'foo', user: @stubs.user, channel: @stubs.DM}
    return

  it 'Should return a message object with raw text and message', (done) ->
    #the shape of this data is an RTM message event passed through SlackClient#messageWrapper
    #see: https://api.slack.com/events/message
    messageData = {
      type: 'message'
      user: @stubs.user,
      channel: @stubs.channel,
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

  it 'Should handle channel_join events as envisioned', ->
    @slackbot.eventHandler {type: 'message', subtype: 'channel_join', user: @stubs.user, channel: @stubs.channel}
    should.equal (@stubs._received instanceof EnterMessage), true
    @stubs._received.user.id.should.equal @stubs.user.id

  it 'Should handle channel_leave events as envisioned', ->
    @slackbot.eventHandler {type: 'message', subtype: 'channel_leave', user: @stubs.user, channel: @stubs.channel}
    should.equal (@stubs._received instanceof LeaveMessage), true
    @stubs._received.user.id.should.equal @stubs.user.id

  it 'Should handle channel_topic events as envisioned', ->
    @slackbot.eventHandler {type: 'message', subtype: 'channel_topic', user: @stubs.user, channel: @stubs.channel}
    should.equal (@stubs._received instanceof TopicMessage), true
    @stubs._received.user.id.should.equal @stubs.user.id

  it 'Should handle group_join events as envisioned', ->
    @slackbot.eventHandler {type: 'message', subtype: 'group_join', user: @stubs.user, channel: @stubs.channel}
    should.equal (@stubs._received instanceof EnterMessage), true
    @stubs._received.user.id.should.equal @stubs.user.id

  it 'Should handle group_leave events as envisioned', ->
    @slackbot.eventHandler {type: 'message', subtype: 'group_leave', user: @stubs.user, channel: @stubs.channel}
    should.equal (@stubs._received instanceof LeaveMessage), true
    @stubs._received.user.id.should.equal @stubs.user.id

  it 'Should handle group_topic events as envisioned', ->
    @slackbot.eventHandler {type: 'message', subtype: 'group_topic', user: @stubs.user, channel: @stubs.channel}
    should.equal (@stubs._received instanceof TopicMessage), true
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
    @slackbot.eventHandler {type: 'message', subtype: 'bot_message', bot: @stubs.bot, channel: @stubs.channel, text: 'Pushing is the answer', returnRawText: true }
    return

  it 'Should ignore messages it sent itself', ->
    @slackbot.eventHandler {type: 'message', subtype: 'bot_message', user: @stubs.self, channel: @stubs.channel, text: 'Ignore me' }
    should.equal @stubs._received, undefined

  it 'Should ignore messages it sent itself, if sent as a botuser', ->
    @slackbot.eventHandler {type: 'message', subtype: 'bot_message', bot: @stubs.self_bot, channel: @stubs.channel, text: 'Ignore me' }
    should.equal @stubs._received, undefined

  it 'Should ignore reaction events that it generated itself', ->
    reactionMessage = { type: 'reaction_removed', user: @stubs.self, reaction: 'thumbsup', event_ts: '1360782804.083113' }
    @slackbot.eventHandler reactionMessage
    should.equal @stubs._received, undefined

  it 'Should ignore reaction events that it generated itself as a botuser', ->
    reactionMessage = { type: 'reaction_added', user: @stubs.self_bot, reaction: 'thumbsup', event_ts: '1360782804.083113' }
    @slackbot.eventHandler reactionMessage
    should.equal @stubs._received, undefined

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

describe 'Robot.react', ->
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

describe 'Users data', ->
  it 'Should add a user data', ->
    @slackbot.updateUserInBrain(@stubs.user)

    user = @slackbot.robot.brain.data.users[@stubs.user.id]
    should.equal user.id, @stubs.user.id
    should.equal user.name, @stubs.user.name
    should.equal user.real_name, @stubs.user.real_name
    should.equal user.email_address, @stubs.user.profile.email
    should.equal user.slack.misc, @stubs.user.misc

  it 'Should add a user data (user with no profile)', ->
    @slackbot.updateUserInBrain(@stubs.usernoprofile)

    user = @slackbot.robot.brain.data.users[@stubs.usernoprofile.id]
    should.equal user.id, @stubs.usernoprofile.id
    should.equal user.name, @stubs.usernoprofile.name
    should.equal user.real_name, @stubs.usernoprofile.real_name
    should.equal user.slack.misc, @stubs.usernoprofile.misc
    (user).should.not.have.ownProperty('email_address')

  it 'Should add a user data (user with no email in profile)', ->
    @slackbot.updateUserInBrain(@stubs.usernoemail)

    user = @slackbot.robot.brain.data.users[@stubs.usernoemail.id]
    should.equal user.id, @stubs.usernoemail.id
    should.equal user.name, @stubs.usernoemail.name
    should.equal user.real_name, @stubs.usernoemail.real_name
    should.equal user.slack.misc, @stubs.usernoemail.misc
    (user).should.not.have.ownProperty('email_address')

  it 'Should modify a user data', ->
    @slackbot.updateUserInBrain(@stubs.user)

    user = @slackbot.robot.brain.data.users[@stubs.user.id]
    should.equal user.id, @stubs.user.id
    should.equal user.name, @stubs.user.name
    should.equal user.real_name, @stubs.user.real_name
    should.equal user.email_address, @stubs.user.profile.email
    should.equal user.slack.misc, @stubs.user.misc

    client = new SlackClient {token: 'xoxb-faketoken'}, @stubs.robot

    user_change_event =
      type: 'user_change'
      user:
        id: @stubs.user.id
        name: 'modified_name'
        real_name: @stubs.user.real_name
        profile:
          email: @stubs.user.profile.email
        client:
          client

    @slackbot.updateUserInBrain(user_change_event)

    user = @slackbot.robot.brain.data.users[@stubs.user.id]
    should.equal user.id, @stubs.user.id
    should.equal user.name, user_change_event.user.name
    should.equal user.real_name, @stubs.user.real_name
    should.equal user.email_address, @stubs.user.profile.email
    should.equal user.slack.misc, undefined
    should.equal user.slack.client, undefined

  it 'Should ignore user data which is undefined', ->
    @slackbot.updateUserInBrain(undefined)
    users = @slackbot.robot.brain.data.users
    should.equal Object.keys(users).length, 0

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
