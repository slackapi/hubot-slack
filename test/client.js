/*
 * decaffeinate suggestions:
 * DS102: Remove unnecessary code created because of implicit returns
 * DS207: Consider shorter variations of null checks
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/main/docs/suggestions.md
 */
const {RtmClient, WebClient, MemoryDataStore} = require('@slack/client');
const SlackClient = require('../src/client');
const should = require('should');
const _ = require('lodash');

describe('Init', function() {
  beforeEach(function() {
    const { stubs, slackbot, client } = require('./stubs.js')();
    this.stubs = stubs;
    this.slackbot = slackbot;
    this.client = client;
  });
  it('Should initialize with an RTM client', function() {
    (this.client.rtm instanceof RtmClient).should.equal(true);
    return this.client.rtm._token.should.equal('xoxb-faketoken');
  });

  it('Should initialize with a Web client', function() {
    (this.client.web instanceof WebClient).should.equal(true);
    return this.client.web._token.should.equal('xoxb-faketoken');
  });

});

describe('connect()', () => {
  beforeEach(function() {
    const { stubs, slackbot, client } = require('./stubs.js')();
    this.stubs = stubs;
    this.slackbot = slackbot;
    this.client = client;
  });
  it('Should be able to connect', function() {
    this.client.connect();
    return this.stubs._connected.should.be.true;
  });
});

describe('onEvent()', function() {
  beforeEach(function() {
    const { stubs, slackbot, client } = require('./stubs.js')();
    this.stubs = stubs;
    this.slackbot = slackbot;
    this.client = client;
  });
  it('should not need to be set', function() {
    this.client.rtm.emit('message', { fake: 'message' });
    return (true).should.be.ok;
  });
  it('should emit pre-processed messages to the callback', function(done) {
    this.client.onEvent(message => {
      message.should.be.ok;
      message.user.real_name.should.equal(this.stubs.user.real_name);
      message.channel.should.equal(this.stubs.channel.id);
      return done();
    });
    // the shape of the following object is a raw RTM message event: https://api.slack.com/events/message
    this.client.rtm.emit('message', {
      type: 'message',
      user: this.stubs.user.id,
      channel: this.stubs.channel.id,
      text: 'blah',
      ts: '1355517523.000005'
    });
    // NOTE: the following check does not appear to work as expected
    return setTimeout(( () => {
      return this.stubs.robot.logger.logs.should.not.have.property('error');
    }
    ), 0);
  });
  it('should successfully convert bot users', function(done) {
    this.client.onEvent(message => {
      message.should.be.ok;
      message.user.id.should.equal(this.stubs.user.id);
      message.channel.should.equal(this.stubs.channel.id);
      return done();
    });
    // the shape of the following object is a raw RTM message event: https://api.slack.com/events/message
    this.client.rtm.emit('message', {
      type: 'message',
      bot_id: 'B123',
      channel: this.stubs.channel.id,
      text: 'blah'
    });
    // NOTE: the following check does not appear to work as expected
    return setTimeout(( () => {
      return this.stubs.robot.logger.logs.should.not.have.property('error');
    }
    ), 0);
  });

  it('should handle undefined bot users', function(done) {
    this.client.onEvent(message => {
      message.should.be.ok;
      message.channel.should.equal(this.stubs.channel.id);
      return done();
    });
    this.client.rtm.emit('message', {
      type: 'message',
      bot_id: 'B789',
      channel: this.stubs.channel.id,
      text: 'blah'
    });

    return setTimeout(( () => {
      return this.stubs.robot.logger.logs.should.not.have.property('error');
    }
    ), 0);
  });

  it('should handle undefined users as envisioned', function(done) {
    this.client.onEvent(message => {
      message.should.be.ok;
      message.channel.should.equal(this.stubs.channel.id);
      return done();
    });
    this.client.rtm.emit('message', {
      type: 'message',
      user: undefined,
      channel: this.stubs.channel.id,
      text: 'eat more veggies'
    });

    return setTimeout(( () => {
      return this.stubs.robot.logger.logs.should.not.have.property('error');
    }
    ), 0);
  });

  it('should update bot id to user representation map', function(done) {
    this.client.onEvent(message => {
      message.should.be.ok;
      this.client.botUserIdMap[this.stubs.bot.id].id.should.equal(this.stubs.user.id);
      return done();
    });
    
    // the shape of the following object is a raw RTM message event: https://api.slack.com/events/message
    this.client.rtm.emit('message', {
      type: 'message',
      bot_id: this.stubs.bot.id,
      channel: this.stubs.channel.id,
      text: 'blah'
    });

    return setTimeout(( () => {
      return this.stubs.robot.logger.logs.should.not.have.property('error');
    }
    ), 0);
  });
  it('should use user representation for bot id in map', function(done) {
    this.client.onEvent(message => {
      message.should.be.ok;
      message.user.id.should.equal(this.stubs.user.id);
      return done();
    });
    
    this.client.botUserIdMap[this.stubs.bot.id] = this.stubs.user;
    // the shape of the following object is a raw RTM message event: https://api.slack.com/events/message
    this.client.rtm.emit('message', {
      type: 'message',
      bot_id: this.stubs.bot.id,
      channel: this.stubs.channel.id,
      text: 'blah'
    });

    return setTimeout(( () => {
      return this.stubs.robot.logger.logs.should.not.have.property('error');
    }
    ), 0);
  });
  it('should log an error when expanded info cannot be fetched using the Web API', function(done) {
    // NOTE: to be certain nothing goes wrong in the rejection handling, the "unhandledRejection" / "rejectionHandled"
    // global events need to be instrumented
    this.client.onEvent(message => done(new Error('A message was emitted')));
    this.client.rtm.emit('message', {
      type: 'message',
      user: 'NOT A USER',
      channel:  this.stubs.channel.id,
      text: 'blah',
      ts: '1355517523.000005'
    });
    return setImmediate(( () => {
      if (this.stubs.robot.logger.logs != null) {
        this.stubs.robot.logger.logs.error.length.should.equal(1);
      }
      return done();
    }
    ), 0);
  });
  
  return it('should use user instead of bot_id', function(done) {
    this.client.onEvent(message => {
      message.should.be.ok;
      message.user.id.should.equal(this.stubs.user.id);
      return done();
    });

    this.client.botUserIdMap[this.stubs.bot.id] = this.stubs.userperiod;
    this.client.rtm.emit('message', {
      type: 'message',
      bot_id: this.stubs.bot.id,
      user: this.stubs.user.id,
      channel: this.stubs.channel.id,
      text: 'blah'
    });

    return setTimeout(( () => {
      return this.stubs.robot.logger.logs.should.not.have.property('error');
    }
    ), 0);
  });
});


describe('on() - DEPRECATED', () => {
  beforeEach(function() {
    const { stubs, slackbot, client } = require('./stubs.js')();
    this.stubs = stubs;
    this.slackbot = slackbot;
    this.client = client;
  });
  it('Should register events on the RTM stream', function() {
    let event = undefined;
    this.client.on('some_event', e => event = e);
    this.client.rtm.emit('some_event', {});
    return event.should.be.ok;
  });
});

describe('disconnect()', function() {
  beforeEach(function() {
    const { stubs, slackbot, client } = require('./stubs.js')();
    this.stubs = stubs;
    this.slackbot = slackbot;
    this.client = client;
  });
  it('Should disconnect RTM', function() {
    this.client.disconnect();
    return this.stubs._connected.should.be.false;
  });
  return it('should remove all RTM listeners - LEGACY', function() {
    this.client.on('some_event', _.noop);
    this.client.disconnect();
    return this.client.rtm.listeners('some_event', true).should.not.be.ok;
  });
});

describe('setTopic()', function() {
  beforeEach(function() {
    const { stubs, slackbot, client } = require('./stubs.js')();
    this.stubs = stubs;
    this.slackbot = slackbot;
    this.client = client;
  });
  it("Should set the topic in a channel", function(done) {
    this.client.setTopic(this.stubs.channel.id, 'iAmTopic');
    return setImmediate(() => {
      this.stubs._topic.should.equal('iAmTopic');
      return done();
    }
    , 0);
  });
  it("should not set the topic in a DM", function(done) {
    this.client.setTopic(this.stubs.DM.id, 'iAmTopic');
    return setTimeout(() => {
      this.stubs.should.not.have.property('_topic');
      // NOTE: no good way to assert that debug log was output
      return done();
    }
    , 0);
  });
  it("should not set the topic in a MPIM", function(done) {
    this.client.setTopic(this.stubs.group.id, 'iAmTopic');
    return setTimeout(() => {
      this.stubs.should.not.have.property('_topic');
      // NOTE: no good way to assert that debug log was output
      return done();
    }
    , 0);
  });
  return it("should log an error if the setTopic web API method fails", function(done) {
    this.client.setTopic('NOT A CONVERSATION', 'iAmTopic');
    return setTimeout(() => {
      this.stubs.should.not.have.property('_topic');
      if (this.stubs.robot.logger.logs != null) {
        this.stubs.robot.logger.logs.error.length.should.equal(1);
      }
      return done();
    }
    , 0);
  });
});

describe('send()', function() {
  beforeEach(function() {
    const { stubs, slackbot, client } = require('./stubs.js')();
    this.stubs = stubs;
    this.slackbot = slackbot;
    this.client = client;
  });
  it('Should send a plain string message to room', function() {
    this.client.send({room: 'room1'}, 'Message');
    this.stubs._msg.should.equal('Message');
    return this.stubs._room.should.equal('room1');
  });

  it('Should send an object message to room', function() {
    this.client.send({room: 'room2'}, {text: 'textMessage'});
    this.stubs._msg.should.equal('textMessage');
    return this.stubs._room.should.equal('room2');
  });

  it('Should be able to send a DM to a user object', function() {
    this.client.send(this.stubs.user, 'DM Message');
    this.stubs._dmmsg.should.equal('DM Message');
    return this.stubs._room.should.equal(this.stubs.user.id);
  });

  it('should not send a message to a user without an ID', function() {
    this.client.send({ name: "my_crufty_username" }, "don't program with usernames");
    return this.stubs._sendCount.should.equal(0);
  });

  it('should log an error when chat.postMessage fails (plain string)', function(done) {
    this.client.send({ room: this.stubs.channelWillFailChatPost }, "Message");
    this.stubs._sendCount.should.equal(0);
    return setImmediate(( () => {
      if (this.stubs.robot.logger.logs != null) {
        this.stubs.robot.logger.logs.error.length.should.equal(1);
      }
      return done();
    }
    ), 0);
  });

  return it('should log an error when chat.postMessage fails (object)', function(done) {
    this.client.send({ room: this.stubs.channelWillFailChatPost }, { text: "textMessage" });
    this.stubs._sendCount.should.equal(0);
    return setImmediate(( () => {
      if (this.stubs.robot.logger.logs != null) {
        this.stubs.robot.logger.logs.error.length.should.equal(1);
      }
      return done();
    }
    ), 0);
  });
});

describe('loadUsers()', function() {
  beforeEach(function() {
    const { stubs, slackbot, client } = require('./stubs.js')();
    this.stubs = stubs;
    this.slackbot = slackbot;
    this.client = client;
  });
  it('should make successive calls to users.list', function() {
    return this.client.loadUsers((err, result) => {
      if (this.stubs != null) {
        this.stubs._listCount.should.equal(2);
      }
      return result.members.length.should.equal(4);
    });
  });
  return it('should handle errors', function() {
    this.stubs._listError = true;
    return this.client.loadUsers((err, result) => {
      return err.should.be.an.Error;
    });
  });
});

describe('Users data', function() {
  beforeEach(function() {
    const { stubs, slackbot, client } = require('./stubs.js')();
    this.stubs = stubs;
    this.slackbot = slackbot;
    this.client = client;
  });
  it('Should add a user data', function() {
    this.client.updateUserInBrain(this.stubs.user);
    const user = this.slackbot.robot.brain.data.users[this.stubs.user.id];
    should.equal(user.id, this.stubs.user.id);
    should.equal(user.name, this.stubs.user.name);
    should.equal(user.real_name, this.stubs.user.real_name);
    should.equal(user.email_address, this.stubs.user.profile.email);
    return should.equal(user.slack.misc, this.stubs.user.misc);
  });

  it('Should add a user data (user with no profile)', function() {
    this.client.updateUserInBrain(this.stubs.usernoprofile);
    const user = this.slackbot.robot.brain.data.users[this.stubs.usernoprofile.id];
    should.equal(user.id, this.stubs.usernoprofile.id);
    should.equal(user.name, this.stubs.usernoprofile.name);
    should.equal(user.real_name, this.stubs.usernoprofile.real_name);
    should.equal(user.slack.misc, this.stubs.usernoprofile.misc);
    return (user).should.not.have.ownProperty('email_address');
  });

  it('Should add a user data (user with no email in profile)', function() {
    this.client.updateUserInBrain(this.stubs.usernoemail);

    const user = this.slackbot.robot.brain.data.users[this.stubs.usernoemail.id];
    should.equal(user.id, this.stubs.usernoemail.id);
    should.equal(user.name, this.stubs.usernoemail.name);
    should.equal(user.real_name, this.stubs.usernoemail.real_name);
    should.equal(user.slack.misc, this.stubs.usernoemail.misc);
    return (user).should.not.have.ownProperty('email_address');
  });

  return it('Should modify a user data', function() {
    this.client.updateUserInBrain(this.stubs.user);

    let user = this.slackbot.robot.brain.data.users[this.stubs.user.id];
    should.equal(user.id, this.stubs.user.id);
    should.equal(user.name, this.stubs.user.name);
    should.equal(user.real_name, this.stubs.user.real_name);
    should.equal(user.email_address, this.stubs.user.profile.email);
    should.equal(user.slack.misc, this.stubs.user.misc);

    const user_change_event = {
      type: 'user_change',
      user: {
        id: this.stubs.user.id,
        name: 'modified_name',
        real_name: this.stubs.user.real_name,
        profile: {
          email: this.stubs.user.profile.email
        }
      }
    };

    this.client.updateUserInBrain(user_change_event);

    user = this.slackbot.robot.brain.data.users[this.stubs.user.id];
    should.equal(user.id, this.stubs.user.id);
    should.equal(user.name, user_change_event.user.name);
    should.equal(user.real_name, this.stubs.user.real_name);
    should.equal(user.email_address, this.stubs.user.profile.email);
    should.equal(user.slack.misc, undefined);
    return should.equal(user.slack.client, undefined);
  });
});

describe('fetchBotUser()', function() {
  beforeEach(function() {
    const { stubs, slackbot, client } = require('./stubs.js')();
    this.stubs = stubs;
    this.slackbot = slackbot;
    this.client = client;
  });
  it('should return user representation from map', function() {
    const {
      user
    } = this.stubs;
    this.client.botUserIdMap[this.stubs.bot.id] = user;
    return this.client.fetchBotUser(this.stubs.bot.id)
    .then(res => res.id.should.equal(user.id));
  });

  it('should return promise if no user representation exists in map', function() {
    const result = this.client.fetchBotUser(this.stubs.bot.id);
    return result.should.be.Promise();
  });

  return it('should return constant data if id is slackbots id', function() {
    const user = this.stubs.slack_bot;
    return this.client.fetchBotUser(this.stubs.slack_bot.id)
    .then(function(res) {
      res.id.should.equal(user.id);
      return res.user_id.should.equal(user.user_id);
    });
  });
});

describe('fetchUser()', function() {
  beforeEach(function() {
    const { stubs, slackbot, client } = require('./stubs.js')();
    this.stubs = stubs;
    this.slackbot = slackbot;
    this.client = client;
  });
  it('should return user representation from brain', function() {
    const {
      user
    } = this.stubs;
    this.client.updateUserInBrain(user);
    return this.client.fetchUser(user.id)
    .then(res => res.id.should.equal(user.id));
  });

  it('should return promise if no user exists in brain', function() {
    const result = this.client.fetchUser(this.stubs.user.id);
    return result.should.be.Promise();
  });
  
  return it('Should sync interacting users when syncing disabled', function() {
    const {
      slackbot
    } = this;
    slackbot.options.disableUserSync = true;
    slackbot.run();

    return this.client.fetchUser(this.stubs.user.id)
    .then(res => slackbot.robot.brain.data.users.should.have.keys('U123'));
  });
});

describe('fetchConversation()', function() {
  beforeEach(function() {
    const { stubs, slackbot, client } = require('./stubs.js')();
    this.stubs = stubs;
    this.slackbot = slackbot;
    this.client = client;
  });
  it('Should remove expired conversation info', function() {
    const {
      channel
    } = this.stubs;
    const {
      client
    } = this;
    client.channelData[channel.id] = {
      channel: {id: 'C123', name: 'foo'},
      updated: this.stubs.expired_timestamp
    };
    return client.fetchConversation(channel.id)
    .then(function(res) {
      res.name.should.equal(channel.name);
      client.channelData.should.have.key('C123');
      return client.channelData['C123'].channel.name.should.equal(channel.name);
    });
  });
  return it('Should return conversation info if not expired', function() {
    const {
      channel
    } = this.stubs;
    const {
      client
    } = this;
    client.channelData[channel.id] = {
      channel: {id: 'C123', name: 'foo'},
      updated: Date.now()
    };
    return client.fetchConversation(channel.id)
    .then(function(res) {
      res.id.should.equal(channel.id);
      client.channelData.should.have.key('C123');
      return client.channelData['C123'].channel.name.should.equal('foo');
    });
  });
});
