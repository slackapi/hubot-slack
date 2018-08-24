{RtmClient, WebClient, MemoryDataStore} = require '@slack/client'
SlackFormatter = require '../src/formatter'
SlackClient = require '../src/client'
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

describe 'onEvent()', ->
  it 'should not need to be set', ->
    @client.rtm.emit('message', { fake: 'message' })
    (true).should.be.ok
  it 'should emit pre-processed messages to the callback', (done) ->
    @client.onEvent (message) =>
      message.should.be.ok
      message.user.real_name.should.equal @stubs.user.real_name
      message.channel.should.equal @stubs.channel.id
      done()
    # the shape of the following object is a raw RTM message event: https://api.slack.com/events/message
    @client.rtm.emit('message', {
      type: 'message',
      user: @stubs.user.id,
      channel: @stubs.channel.id,
      text: 'blah',
      ts: '1355517523.000005'
    })
    # NOTE: the following check does not appear to work as expected
    setTimeout(( =>
      @stubs.robot.logger.logs.should.not.have.property('error')
    ), 0);
  it 'should successfully convert bot users', (done) ->
    @client.onEvent (message) =>
      message.should.be.ok
      message.user.id.should.equal @stubs.user.id
      message.channel.should.equal @stubs.channel.id
      done()
    # the shape of the following object is a raw RTM message event: https://api.slack.com/events/message
    @client.rtm.emit('message', {
      type: 'message',
      bot_id: 'B123'
      channel: @stubs.channel.id,
      text: 'blah'
    })
    # NOTE: the following check does not appear to work as expected
    setTimeout(( =>
      @stubs.robot.logger.logs.should.not.have.property('error')
    ), 0);

  it 'should handle undefined bot users', (done) ->
    @client.onEvent (message) =>
      message.should.be.ok
      message.channel.should.equal @stubs.channel.id
      done()
    @client.rtm.emit('message', {
      type: 'message',
      bot_id: 'B789',
      channel: @stubs.channel.id,
      text: 'blah'
    })

    setTimeout(( =>
      @stubs.robot.logger.logs.should.not.have.property('error')
    ), 0);

  it 'should handle undefined users as envisioned', (done) ->
    @client.onEvent (message) =>
      message.should.be.ok
      message.channel.should.equal @stubs.channel.id
      done()
    @client.rtm.emit('message', {
      type: 'message',
      user: undefined,
      channel: @stubs.channel.id,
      text: 'eat more veggies'
    })

    setTimeout(( =>
      @stubs.robot.logger.logs.should.not.have.property('error')
    ), 0);

  it 'should update bot id to user representation map', (done) ->
    @client.onEvent (message) =>
      message.should.be.ok
      @client.botUserIdMap[@stubs.bot.id].id.should.equal @stubs.user.id
      done()
    
    # the shape of the following object is a raw RTM message event: https://api.slack.com/events/message
    @client.rtm.emit('message', {
      type: 'message',
      bot_id: @stubs.bot.id,
      channel: @stubs.channel.id,
      text: 'blah'
    })

    setTimeout(( =>
      @stubs.robot.logger.logs.should.not.have.property('error')
    ), 0);
  it 'should use user representation for bot id in map', (done) ->
    @client.onEvent (message) =>
      message.should.be.ok
      message.user.id.should.equal @stubs.user.id
      done()
    
    @client.botUserIdMap[@stubs.bot.id] = @stubs.user
    # the shape of the following object is a raw RTM message event: https://api.slack.com/events/message
    @client.rtm.emit('message', {
      type: 'message',
      bot_id: @stubs.bot.id,
      channel: @stubs.channel.id,
      text: 'blah'
    })

    setTimeout(( =>
      @stubs.robot.logger.logs.should.not.have.property('error')
    ), 0);
  it 'should log an error when expanded info cannot be fetched using the Web API', (done) ->
    # NOTE: to be certain nothing goes wrong in the rejection handling, the "unhandledRejection" / "rejectionHandled"
    # global events need to be instrumented
    @client.onEvent (message) ->
      done(new Error('A message was emitted'))
    @client.rtm.emit('message', {
      type: 'message',
      user: 'NOT A USER',
      channel:  @stubs.channel.id,
      text: 'blah',
      ts: '1355517523.000005'
    })
    setImmediate(( =>
      @stubs.robot.logger.logs?.error.length.should.equal 1
      done()
    ), 0);
  
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
    setImmediate(() =>
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
  it "should not set the topic in a MPIM", (done) ->
    @client.setTopic @stubs.group.id, 'iAmTopic'
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

  it 'should not send a message to a user without an ID', ->
    @client.send { name: "my_crufty_username" }, "don't program with usernames"
    @stubs._sendCount.should.equal 0

  it 'should log an error when chat.postMessage fails (plain string)', ->
    @client.send { room: @stubs.channelWillFailChatPost }, "Message"
    @stubs._sendCount.should.equal 0
    setImmediate(( =>
      @stubs.robot.logger.logs?.error.length.should.equal 1
      done()
    ), 0);

  it 'should log an error when chat.postMessage fails (object)', ->
    @client.send { room: @stubs.channelWillFailChatPost }, { text: "textMessage" }
    @stubs._sendCount.should.equal 0
    setImmediate(( =>
      @stubs.robot.logger.logs?.error.length.should.equal 1
      done()
    ), 0);

describe 'loadUsers()', ->
  it 'should make successive calls to users.list', ->
    @client.loadUsers (err, result) =>
      @stubs?._listCount.should.equal 2
      result.members.length.should.equal 4
  it 'should handle errors', ->
    @stubs._listError = true
    @client.loadUsers (err, result) =>
      err.should.be.an.Error

describe 'Users data', ->
  it 'Should add a user data', ->
    @client.updateUserInBrain(@stubs.user)

    user = @slackbot.robot.brain.data.users[@stubs.user.id]
    should.equal user.id, @stubs.user.id
    should.equal user.name, @stubs.user.name
    should.equal user.real_name, @stubs.user.real_name
    should.equal user.email_address, @stubs.user.profile.email
    should.equal user.slack.misc, @stubs.user.misc

  it 'Should add a user data (user with no profile)', ->
    @client.updateUserInBrain(@stubs.usernoprofile)

    user = @slackbot.robot.brain.data.users[@stubs.usernoprofile.id]
    should.equal user.id, @stubs.usernoprofile.id
    should.equal user.name, @stubs.usernoprofile.name
    should.equal user.real_name, @stubs.usernoprofile.real_name
    should.equal user.slack.misc, @stubs.usernoprofile.misc
    (user).should.not.have.ownProperty('email_address')

  it 'Should add a user data (user with no email in profile)', ->
    @client.updateUserInBrain(@stubs.usernoemail)

    user = @slackbot.robot.brain.data.users[@stubs.usernoemail.id]
    should.equal user.id, @stubs.usernoemail.id
    should.equal user.name, @stubs.usernoemail.name
    should.equal user.real_name, @stubs.usernoemail.real_name
    should.equal user.slack.misc, @stubs.usernoemail.misc
    (user).should.not.have.ownProperty('email_address')

  it 'Should modify a user data', ->
    @client.updateUserInBrain(@stubs.user)

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

    @client.updateUserInBrain(user_change_event)

    user = @slackbot.robot.brain.data.users[@stubs.user.id]
    should.equal user.id, @stubs.user.id
    should.equal user.name, user_change_event.user.name
    should.equal user.real_name, @stubs.user.real_name
    should.equal user.email_address, @stubs.user.profile.email
    should.equal user.slack.misc, undefined
    should.equal user.slack.client, undefined

describe 'fetchBotUser()', ->
  it 'should return user representation from map', ->
    user = @stubs.user
    @client.botUserIdMap[@stubs.bot.id] = user
    @client.fetchBotUser @stubs.bot.id
    .then((res) ->
      res.id.should.equal user.id
    )

  it 'should return promise if no user representation exists in map', ->
    result = @client.fetchBotUser @stubs.bot.id
    result.should.be.Promise()

  it 'should return constant data if id is slackbots id', ->
    user = @stubs.slack_bot
    @client.fetchBotUser @stubs.slack_bot.id
    .then((res) ->
      res.id.should.equal user.id
      res.user_id.should.equal user.user_id
    )

describe 'fetchUser()', ->
  it 'should return user representation from brain', ->
    user = @stubs.user
    @client.updateUserInBrain(user)
    @client.fetchUser user.id
    .then((res) ->
      res.id.should.equal user.id
    )

  it 'should return promise if no user exists in brain', ->
    result = @client.fetchUser @stubs.user.id
    result.should.be.Promise()
  
  it 'Should sync interacting users when syncing disabled', ->
    slackbot = @slackbot
    slackbot.options.disableUserSync = true
    slackbot.run()

    @client.fetchUser @stubs.user.id
    .then((res) ->
      slackbot.robot.brain.data.users.should.have.keys('U123')
    )

describe 'fetchConversation()', ->
  it 'Should remove expired conversation info', ->
    channel = @stubs.channel
    client = @client
    client.channelData[channel.id] = {
      channel: {id: 'C123', name: 'foo'},
      updated: @stubs.expired_timestamp
    }
    client.fetchConversation channel.id
    .then((res) ->
      res.name.should.equal channel.name
      client.channelData.should.have.key('C123')
      client.channelData['C123'].channel.name.should.equal channel.name
    )
  it 'Should return conversation info if not expired', ->
    channel = @stubs.channel
    client = @client
    client.channelData[channel.id] = {
      channel: {id: 'C123', name: 'foo'},
      updated: Date.now()
    }
    client.fetchConversation channel.id
    .then((res) ->
      res.id.should.equal channel.id
      client.channelData.should.have.key('C123')
      client.channelData['C123'].channel.name.should.equal 'foo'
    )
