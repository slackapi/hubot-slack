/*
 * decaffeinate suggestions:
 * DS102: Remove unnecessary code created because of implicit returns
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/main/docs/suggestions.md
 */
const should = require('should');
const chai = require('chai');
const mockery = require('mockery');
const hubotSlackMock = require('../slack.js');
mockery.registerMock('hubot-slack', hubotSlackMock);

const { EnterMessage, LeaveMessage, TopicMessage, CatchAllMessage, Robot, loadBot, Adapter } = require.main.require('hubot');
const { SlackTextMessage, ReactionMessage, PresenceMessage, FileSharedMessage } = require('../src/message');
const SlackClient = require('../src/client');
const _ = require('lodash');
const SlackBot = require('../src/bot.js');

describe('Adapter', function() {
  
  beforeEach(function() {
    const {stubs, slackbot} = require('./stubs.js')();
    this.stubs = stubs;
    this.slackbot = slackbot;
  });
  
  before(() => mockery.enable({
    warnOnUnregistered: false
  }));
  
  after(() => mockery.disable());
  
  it('Should initialize with a robot', function() {
    return this.slackbot.robot.should.eql(this.stubs.robot);
  });

  return it('Should load an instance of Robot with extended methods', function() {
    const loadedRobot = loadBot('', 'slack', false, 'Hubot');
    
    // Check to make sure presenceChange and react are loaded to Robot
    loadedRobot.presenceChange.should.be.an.instanceOf(Function).with.lengthOf(3);
    loadedRobot.react.should.be.an.instanceOf(Function).with.lengthOf(3);
    return loadedRobot.fileShared.should.be.an.instanceOf(Function).with.lengthOf(3);
  });
});

describe('Connect', () => {
  beforeEach(function() {
    const {stubs, slackbot} = require('./stubs.js')();
    this.stubs = stubs;
    this.slackbot = slackbot;
  });
  it('Should connect successfully', function() {
    this.slackbot.run();
    return this.stubs._connected.should.be.true;
  })
});

describe('Authenticate', () => {
  beforeEach(function() {
    const {stubs, slackbot} = require('./stubs.js')();
    this.stubs = stubs;
    this.slackbot = slackbot;
  });

  it('Should authenticate successfully', function() {
    const {logger} = this.slackbot.robot;
    const start = { self: {
      id: this.stubs.self.id,
      name: this.stubs.self.name
    },
    team: {
      id: this.stubs.team.id,
      name: this.stubs.team.name
    },
    users: [
      this.stubs.self,
      this.stubs.user
    ]
  };

    this.slackbot.authenticated(start);
    this.slackbot.self.id.should.equal(this.stubs.self.id);
    this.slackbot.robot.name.should.equal(this.stubs.self.name);
    logger.logs["info"].length.should.be.above(0);
    return logger.logs["info"][logger.logs["info"].length-1].should.equal(`Logged in as @${this.stubs.self.name} in workspace ${this.stubs.team.name}`);
  });
});

describe('Logger', function() {
  beforeEach(function() {
    const {stubs, slackbot} = require('./stubs.js')();
    this.stubs = stubs;
    this.slackbot = slackbot;
  });

  it('It should log missing token error', function() {
    const {logger} = this.slackbot.robot;
    this.slackbot.options.token = null;
    this.slackbot.run();
    logger.logs["error"].length.should.be.above(0);
    return logger.logs["error"][logger.logs["error"].length-1].should.equal('No token provided to Hubot');
  });

  return it('It should log invalid token error', function() {
    const {logger} = this.slackbot.robot;
    this.slackbot.options.token = "ABC123";
    this.slackbot.run() -
    logger.logs["error"].length.should.be.above(0);
    return logger.logs["error"][logger.logs["error"].length-1].should.equal('Invalid token provided, please follow the upgrade instructions');
  });
});

describe('Disable Sync', function() {
  beforeEach(function() {
    const {stubs, slackbot} = require('./stubs.js')();
    this.stubs = stubs;
    this.slackbot = slackbot;
  });

  it('Should sync users by default', function() {
    this.slackbot.run();
    return this.slackbot.robot.brain.data.users.should.have.keys('1','2','3','4');
  });

  return it('Should not sync users when disabled', function() {
    this.slackbot.options.disableUserSync = true;
    this.slackbot.run();
    return this.slackbot.robot.brain.data.users.should.be.empty();
  });
});

  // Test moved to fetchUsers() in client.js because of change in code logic
  //it 'Should still sync interacting users when disabled'

describe('Send Messages', function() {
  beforeEach(function() {
    const {stubs, slackbot} = require('./stubs.js')();
    this.stubs = stubs;
    this.slackbot = slackbot;
  });

  it('Should send a message', function() {
    this.slackbot.send({room: this.stubs.channel.id}, 'message');
    this.stubs._sendCount.should.equal(1);
    return this.stubs._msg.should.equal('message');
  });

  it('Should send multiple messages', function() {
    this.slackbot.send({room: this.stubs.channel.id}, 'one', 'two', 'three');
    return this.stubs._sendCount.should.equal(3);
  });

  it('Should not send empty messages', function() {
    this.slackbot.send({room: this.stubs.channel.id}, 'Hello', '', '', 'world!');
    return this.stubs._sendCount.should.equal(2);
  });

  it('Should not fail for inexistant user', function() {
    return chai.expect(() => this.slackbot.send({room: 'U987'}, 'Hello')).to.not.throw();
  });

  it('Should open a DM channel if needed', function() {
    const msg = 'Test';
    this.slackbot.send({room: this.stubs.user.id}, msg);
    return this.stubs._dmmsg.should.eql(msg);
  });

  it('Should send a message to a user', function() {
    this.slackbot.send(this.stubs.user, 'message');
    this.stubs._dmmsg.should.eql('message');
    return this.stubs._room.should.eql(this.stubs.user.id);
  });

  return it('Should send a message with a callback', function(done) {
    this.slackbot.send({room: this.stubs.channel.id}, 'message', done);
    this.stubs._sendCount.should.equal(1);
    return this.stubs._msg.should.equal('message');
  });
});

describe('Client sending message', function() {
  beforeEach(function() {
    const { stubs, slackbot, client } = require('./stubs.js')();
    this.stubs = stubs;
    this.slackbot = slackbot;
    this.client = client;
  });

  it('Should append as_user = true', function() {
    this.client.send({room: this.stubs.channel.id}, {text: 'foo', user: this.stubs.user, channel: this.stubs.channel.id});
    return this.stubs._opts.as_user.should.eql(true);
  });

  return it('Should append as_user = true only as a default', function() {
    this.client.send({room: this.stubs.channel.id}, {text: 'foo', user: this.stubs.user, channel: this.stubs.channel.id, as_user: false});
    return this.stubs._opts.as_user.should.eql(false);
  });
});

describe('Reply to Messages', function() {
  beforeEach(function() {
    const {stubs, slackbot} = require('./stubs.js')();
    this.stubs = stubs;
    this.slackbot = slackbot;
  });

  it('Should mention the user in a reply sent in a channel', function() {
    this.slackbot.reply({user: this.stubs.user, room: this.stubs.channel.id}, 'message');
    this.stubs._sendCount.should.equal(1);
    return this.stubs._msg.should.equal(`<@${this.stubs.user.id}>: message`);
  });

  it('Should mention the user in multiple replies sent in a channel', function() {
    this.slackbot.reply({user: this.stubs.user, room: this.stubs.channel.id}, 'one', 'two', 'three');
    this.stubs._sendCount.should.equal(3);
    return this.stubs._msg.should.equal(`<@${this.stubs.user.id}>: three`);
  });

  it('Should send nothing if messages are empty', function() {
    this.slackbot.reply({user: this.stubs.user, room: this.stubs.channel.id}, '');
    return this.stubs._sendCount.should.equal(0);
  });

  it('Should NOT mention the user in a reply sent in a DM', function() {
    this.slackbot.reply({user: this.stubs.user, room: this.stubs.DM.id }, 'message');
    this.stubs._sendCount.should.equal(1);
    return this.stubs._dmmsg.should.equal("message");
  });

  return it('Should call the callback', function(done) {
    this.slackbot.reply({user: this.stubs.user, room: this.stubs.channel.id}, 'message', done);
    this.stubs._sendCount.should.equal(1);
    return this.stubs._msg.should.equal(`<@${this.stubs.user.id}>: message`);
  });
});

describe('Setting the channel topic', function() {
  beforeEach(function() {
    const {stubs, slackbot} = require('./stubs.js')();
    this.stubs = stubs;
    this.slackbot = slackbot;
  });

  it('Should set the topic in channels', function(done) {
    this.stubs.receiveMock.onTopic = function(topic) {
      topic.should.equal('channel');
      return done();
    };
    this.slackbot.setTopic({room: this.stubs.channel.id}, 'channel');
  });

  return it('Should NOT set the topic in DMs', function() {
    this.slackbot.setTopic({room: 'D1232'}, 'DM');
    return should.not.exists(this.stubs._topic);
  });
});

describe('Receiving an error event', function() {
  beforeEach(function() {
    const {stubs, slackbot} = require('./stubs.js')();
    this.stubs = stubs;
    this.slackbot = slackbot;
  });
  it('Should propagate that error', function() {
    this.hit = false;
    this.slackbot.robot.on('error', error => {
      error.msg.should.equal('ohno');
      return this.hit = true;
    });
    this.hit.should.equal(false);
    this.slackbot.error({msg: 'ohno', code: -2});
    return this.hit.should.equal(true);
  });

  return it('Should handle rate limit errors', function() {
    const {logger} = this.slackbot.robot;
    this.slackbot.error({msg: 'ratelimit', code: -1});
    return logger.logs["error"].length.should.be.above(0);
  });
});

describe('Handling incoming messages', function() {
  beforeEach(function() {
    const {stubs, slackbot} = require('./stubs.js')();
    this.stubs = stubs;
    this.slackbot = slackbot;
  });

  it('Should handle regular messages as hoped and dreamed', function(done) {
    this.stubs.receiveMock.onReceived = function(msg) {
      msg.text.should.equal('foo');
      return done();
    };
    this.slackbot.eventHandler({type: 'message', text: 'foo', user: this.stubs.user, channel: this.stubs.channel.id });
  });

  it('Should handle broadcasted messages', function(done) {
    this.stubs.receiveMock.onReceived = function(msg) {
      msg.text.should.equal('foo');
      return done();
    };
    this.slackbot.eventHandler({type: 'message', text: 'foo', subtype: 'thread_broadcast', user: this.stubs.user, channel: this.stubs.channel.id });
  });

  it('Should prepend our name to a name-lacking message addressed to us in a DM', function(done) {
    const bot_name = this.slackbot.robot.name;
    this.stubs.receiveMock.onReceived = function(msg) {
      msg.text.should.equal(`${bot_name} foo`);
      return done();
    };
    this.slackbot.eventHandler({type: 'message', text: "foo", user: this.stubs.user, channel: this.stubs.DM.id});
  });

  it('Should NOT prepend our name to a name-containing message addressed to us in a DM', function(done) {
    const bot_name = this.slackbot.robot.name;
    this.stubs.receiveMock.onReceived = function(msg) {
      msg.text.should.equal(`${bot_name} foo`);
      return done();
    };
    this.slackbot.eventHandler({type: 'message', text: `${bot_name} foo`, user: this.stubs.user, channel: this.stubs.DM.id});
  });

  it('Should return a message object with raw text and message', function(done) {
    //the shape of this data is an RTM message event passed through SlackClient#messageWrapper
    //see: https://api.slack.com/events/message
    const messageData = {
      type: 'message',
      user: this.stubs.user,
      channel: this.stubs.channel.id,
      text: 'foo <http://www.example.com> bar',
    };
    this.stubs.receiveMock.onReceived = function(msg) {
      should.equal((msg instanceof SlackTextMessage), true);
      should.equal(msg.text, "foo http://www.example.com bar");
      should.equal(msg.rawText, "foo <http://www.example.com> bar");
      should.equal(msg.rawMessage, messageData);
      return done();
    };
    this.slackbot.eventHandler(messageData);
  });

  it('Should handle member_joined_channel events as envisioned', function() {
    this.slackbot.eventHandler({
      type: 'member_joined_channel',
      user: this.stubs.user,
      channel: this.stubs.channel.id,
      ts: this.stubs.event_timestamp
    });
    should.equal(this.stubs._received.constructor.name, "EnterMessage");
    should.equal(this.stubs._received.ts, this.stubs.event_timestamp);
    return this.stubs._received.user.id.should.equal(this.stubs.user.id);
  });

  it('Should handle member_left_channel events as envisioned', function() {
    this.slackbot.eventHandler({
      type: 'member_left_channel',
      user: this.stubs.user,
      channel: this.stubs.channel.id,
      ts: this.stubs.event_timestamp
    });
    should.equal(this.stubs._received.constructor.name, "LeaveMessage");
    should.equal(this.stubs._received.ts, this.stubs.event_timestamp);
    return this.stubs._received.user.id.should.equal(this.stubs.user.id);
  });

  it('Should handle channel_topic events as envisioned', function() {
    this.slackbot.eventHandler({type: 'message', subtype: 'channel_topic', user: this.stubs.user, channel: this.stubs.channel.id});
    should.equal(this.stubs._received.constructor.name, "TopicMessage");
    return this.stubs._received.user.id.should.equal(this.stubs.user.id);
  });

  it('Should handle group_topic events as envisioned', function() {
    this.slackbot.eventHandler({type: 'message', subtype: 'group_topic', user: this.stubs.user, channel: this.stubs.channel.id});
    should.equal(this.stubs._received.constructor.name, "TopicMessage");
    return this.stubs._received.user.id.should.equal(this.stubs.user.id);
  });

  it('Should handle reaction_added events as envisioned', function() {
    const reactionMessage = {
      type: 'reaction_added', user: this.stubs.user, item_user: this.stubs.self,
      item: { type: 'message', channel: this.stubs.channel.id, ts: '1360782804.083113'
      },
      reaction: 'thumbsup', event_ts: '1360782804.083113'
    };
    this.slackbot.eventHandler(reactionMessage);
    should.equal((this.stubs._received instanceof ReactionMessage), true);
    should.equal(this.stubs._received.user.id, this.stubs.user.id);
    should.equal(this.stubs._received.user.room, this.stubs.channel.id);
    should.equal(this.stubs._received.item_user.id, this.stubs.self.id);
    should.equal(this.stubs._received.type, 'added');
    return should.equal(this.stubs._received.reaction, 'thumbsup');
  });

  it('Should handle reaction_removed events as envisioned', function() {
    const reactionMessage = {
      type: 'reaction_removed', user: this.stubs.user, item_user: this.stubs.self,
      item: { type: 'message', channel: this.stubs.channel.id, ts: '1360782804.083113'
      },
      reaction: 'thumbsup', event_ts: '1360782804.083113'
    };
    this.slackbot.eventHandler(reactionMessage);
    should.equal((this.stubs._received instanceof ReactionMessage), true);
    should.equal(this.stubs._received.user.id, this.stubs.user.id);
    should.equal(this.stubs._received.user.room, this.stubs.channel.id);
    should.equal(this.stubs._received.item_user.id, this.stubs.self.id);
    should.equal(this.stubs._received.type, 'removed');
    return should.equal(this.stubs._received.reaction, 'thumbsup');
  });

  it('Should not crash with bot messages', function(done) {
    this.stubs.receiveMock.onReceived = function(msg) {
      should.equal((msg instanceof SlackTextMessage), true);
      return done();
    };
    this.slackbot.eventHandler({type: 'message', subtype: 'bot_message', user: this.stubs.user, channel: this.stubs.channel.id, text: 'Pushing is the answer', returnRawText: true });
  });

  it('Should handle single user presence_change events as envisioned', function() {
    this.slackbot.robot.brain.userForId(this.stubs.user.id, this.stubs.user);
    const presenceMessage = {
      type: 'presence_change', user: this.stubs.user, presence: 'away'
    };
    this.slackbot.eventHandler(presenceMessage);
    should.equal((this.stubs._received instanceof PresenceMessage), true);
    should.equal(this.stubs._received.users[0].id, this.stubs.user.id);
    return this.stubs._received.users.length.should.equal(1);
  });

  it('Should handle presence_change events as envisioned', function() {
    this.slackbot.robot.brain.userForId(this.stubs.user.id, this.stubs.user);
    const presenceMessage = {
      type: 'presence_change', users: [this.stubs.user], presence: 'away'
    };
    this.slackbot.eventHandler(presenceMessage);
    should.equal((this.stubs._received instanceof PresenceMessage), true);
    should.equal(this.stubs._received.users[0].id, this.stubs.user.id);
    return this.stubs._received.users.length.should.equal(1);
  });

  it('Should ignore messages it sent itself', function() {
    this.slackbot.eventHandler({type: 'message', subtype: 'bot_message', user: this.stubs.self, channel: this.stubs.channel.id, text: 'Ignore me' });
    return should.equal(this.stubs._received, undefined);
  });

  it('Should ignore reaction events that it generated itself', function() {
    const reactionMessage = { type: 'reaction_removed', user: this.stubs.self, reaction: 'thumbsup', event_ts: '1360782804.083113' };
    this.slackbot.eventHandler(reactionMessage);
    return should.equal(this.stubs._received, undefined);
  });

  it('Should handle empty users as envisioned', function(done){
    this.stubs.receiveMock.onReceived = function(msg) {
      should.equal((msg instanceof SlackTextMessage), true);
      return done();
    };
    this.slackbot.eventHandler({type: 'message', subtype: 'bot_message', user: {}, channel: this.stubs.channel.id, text: 'Foo'});
  });

  it('Should handle reaction events from users who are in different workspace in shared channel', function() {
    const reactionMessage = {
      type: 'reaction_added', user: this.stubs.org_user_not_in_workspace_in_channel, item_user: this.stubs.self,
      item: { type: 'message', channel: this.stubs.channel.id, ts: '1360782804.083113'
      },
      reaction: 'thumbsup', event_ts: '1360782804.083113'
    };

    this.slackbot.eventHandler(reactionMessage);
    should.equal((this.stubs._received instanceof ReactionMessage), true);
    should.equal(this.stubs._received.user.id, this.stubs.org_user_not_in_workspace_in_channel.id);
    should.equal(this.stubs._received.user.room, this.stubs.channel.id);
    should.equal(this.stubs._received.item_user.id, this.stubs.self.id);
    should.equal(this.stubs._received.type, 'added');
    return should.equal(this.stubs._received.reaction, 'thumbsup');
  });
    
  return it('Should handle file_shared events as envisioned', function() {
    const fileMessage = {
      type: 'file_shared', user: this.stubs.user,
      file_id: 'F2147483862', event_ts: '1360782804.083113'
    };
    this.slackbot.eventHandler(fileMessage);
    should.equal((this.stubs._received instanceof FileSharedMessage), true);
    should.equal(this.stubs._received.user.id, this.stubs.user.id);
    return should.equal(this.stubs._received.file_id, 'F2147483862');
  });
});

describe('Robot.react DEPRECATED', function() {
  beforeEach(function() {
    const {stubs, slackbot} = require('./stubs.js')();
    this.stubs = stubs;
    this.slackbot = slackbot;
    const user = { id: this.stubs.user.id, room: this.stubs.channel.id };
    const item = {
      type: 'message', channel: this.stubs.channel.id, ts: '1360782804.083113'
    };
    this.reactionMessage = new ReactionMessage(
      'reaction_added', user, 'thumbsup', item, '1360782804.083113'
    );
    return this.handleReaction = msg => `${msg.reaction} handled`;
  });

  it('Should register a Listener with callback only', function() {
    this.slackbot.robot.react(this.handleReaction);
    const listener = this.slackbot.robot.listeners.shift();
    listener.matcher(this.reactionMessage).should.be.true;
    listener.options.should.eql({id: null});
    return listener.callback(this.reactionMessage).should.eql('thumbsup handled');
  });

  it('Should register a Listener with opts and callback', function() {
    this.slackbot.robot.react({id: 'foobar'}, this.handleReaction);
    const listener = this.slackbot.robot.listeners.shift();
    listener.matcher(this.reactionMessage).should.be.true;
    listener.options.should.eql({id: 'foobar'});
    return listener.callback(this.reactionMessage).should.eql('thumbsup handled');
  });

  it('Should register a Listener with matcher and callback', function() {
    const matcher = msg => msg.type === 'added';
    this.slackbot.robot.react(matcher, this.handleReaction);
    const listener = this.slackbot.robot.listeners.shift();
    listener.matcher(this.reactionMessage).should.be.true;
    listener.options.should.eql({id: null});
    return listener.callback(this.reactionMessage).should.eql('thumbsup handled');
  });

  it('Should register a Listener with matcher, opts, and callback', function() {
    const matcher = msg => (msg.type === 'removed') || (msg.reaction === 'thumbsup');
    this.slackbot.robot.react(matcher, {id: 'foobar'}, this.handleReaction);
    const listener = this.slackbot.robot.listeners.shift();
    listener.matcher(this.reactionMessage).should.be.true;
    listener.options.should.eql({id: 'foobar'});
    return listener.callback(this.reactionMessage).should.eql('thumbsup handled');
  });

  return it('Should register a Listener that does not match the ReactionMessage', function() {
    const matcher = msg => msg.type === 'removed';
    this.slackbot.robot.react(matcher, this.handleReaction);
    const listener = this.slackbot.robot.listeners.shift();
    return listener.matcher(this.reactionMessage).should.be.false;
  });
});
    
describe('Robot.fileShared', function() {
  beforeEach(function() {
    const {stubs, slackbot} = require('./stubs.js')();
    this.stubs = stubs;
    this.slackbot = slackbot;
    const user = { id: this.stubs.user.id, room: this.stubs.channel.id };
    this.fileSharedMessage = new FileSharedMessage(user, "F2147483862", '1360782804.083113');
    return this.handleFileShared = msg => `${msg.file_id} shared`;
  });

  it('Should register a Listener with callback only', function() {
    this.slackbot.robot.fileShared(this.handleFileShared);
    const listener = this.slackbot.robot.listeners.shift();
    listener.matcher(this.fileSharedMessage).should.be.true;
    listener.options.should.eql({id: null});
    return listener.callback(this.fileSharedMessage).should.eql('F2147483862 shared');
  });
    
  it('Should register a Listener with opts and callback', function() {
    this.slackbot.robot.fileShared({id: 'foobar'}, this.handleFileShared);
    const listener = this.slackbot.robot.listeners.shift();
    listener.matcher(this.fileSharedMessage).should.be.true;
    listener.options.should.eql({id: 'foobar'});
    return listener.callback(this.fileSharedMessage).should.eql('F2147483862 shared');
  });

  it('Should register a Listener with matcher and callback', function() {
    const matcher = msg => msg.file_id === 'F2147483862';
    this.slackbot.robot.fileShared(matcher, this.handleFileShared);
    const listener = this.slackbot.robot.listeners.shift();
    listener.matcher(this.fileSharedMessage).should.be.true;
    listener.options.should.eql({id: null});
    return listener.callback(this.fileSharedMessage).should.eql('F2147483862 shared');
  });

  it('Should register a Listener with matcher, opts, and callback', function() {
    const matcher = msg => msg.file_id === 'F2147483862';
    this.slackbot.robot.fileShared(matcher, {id: 'foobar'}, this.handleFileShared);
    const listener = this.slackbot.robot.listeners.shift();
    listener.matcher(this.fileSharedMessage).should.be.true;
    listener.options.should.eql({id: 'foobar'});
    return listener.callback(this.fileSharedMessage).should.eql('F2147483862 shared');
  });

  return it('Should register a Listener that does not match the ReactionMessage', function() {
    const matcher = msg => msg.file_id === 'J12387ALDFK';
    this.slackbot.robot.fileShared(matcher, this.handleFileShared);
    const listener = this.slackbot.robot.listeners.shift();
    return listener.matcher(this.fileSharedMessage).should.be.false;
  });
});

describe('Robot.hearReaction', function() {
  beforeEach(function() {
    const {stubs, slackbot} = require('./stubs.js')();
    this.stubs = stubs;
    this.slackbot = slackbot;
    const user = { id: this.stubs.user.id, room: this.stubs.channel.id };
    const item = {
      type: 'message', channel: this.stubs.channel.id, ts: '1360782804.083113'
    };
    this.reactionMessage = new ReactionMessage(
      'reaction_added', user, 'thumbsup', item, '1360782804.083113'
    );
    return this.handleReaction = msg => `${msg.reaction} handled`;
  });

  it('Should register a Listener with callback only', function() {
    this.slackbot.robot.hearReaction(this.handleReaction);
    const listener = this.slackbot.robot.listeners.shift();
    listener.matcher(this.reactionMessage).should.be.true;
    listener.options.should.eql({id: null});
    return listener.callback(this.reactionMessage).should.eql('thumbsup handled');
  });

  it('Should register a Listener with opts and callback', function() {
    this.slackbot.robot.hearReaction({id: 'foobar'}, this.handleReaction);
    const listener = this.slackbot.robot.listeners.shift();
    listener.matcher(this.reactionMessage).should.be.true;
    listener.options.should.eql({id: 'foobar'});
    return listener.callback(this.reactionMessage).should.eql('thumbsup handled');
  });

  it('Should register a Listener with matcher and callback', function() {
    const matcher = msg => msg.type === 'added';
    this.slackbot.robot.hearReaction(matcher, this.handleReaction);
    const listener = this.slackbot.robot.listeners.shift();
    listener.matcher(this.reactionMessage).should.be.true;
    listener.options.should.eql({id: null});
    return listener.callback(this.reactionMessage).should.eql('thumbsup handled');
  });

  it('Should register a Listener with matcher, opts, and callback', function() {
    const matcher = msg => (msg.type === 'removed') || (msg.reaction === 'thumbsup');
    this.slackbot.robot.hearReaction(matcher, {id: 'foobar'}, this.handleReaction);
    const listener = this.slackbot.robot.listeners.shift();
    listener.matcher(this.reactionMessage).should.be.true;
    listener.options.should.eql({id: 'foobar'});
    return listener.callback(this.reactionMessage).should.eql('thumbsup handled');
  });

  return it('Should register a Listener that does not match the ReactionMessage', function() {
    const matcher = msg => msg.type === 'removed';
    this.slackbot.robot.hearReaction(matcher, this.handleReaction);
    const listener = this.slackbot.robot.listeners.shift();
    return listener.matcher(this.reactionMessage).should.be.false;
  });
});

describe('Users data', function() {
  beforeEach(function() {
    const {stubs, slackbot} = require('./stubs.js')();
    this.stubs = stubs;
    this.slackbot = slackbot;
  });
  it('Should load users data from web api', function() {
    this.slackbot.usersLoaded(null, this.stubs.responseUsersList);

    const user = this.slackbot.robot.brain.data.users[this.stubs.user.id];
    should.equal(user.id, this.stubs.user.id);
    should.equal(user.name, this.stubs.user.name);
    should.equal(user.real_name, this.stubs.user.real_name);
    should.equal(user.email_address, this.stubs.user.profile.email);
    should.equal(user.slack.misc, this.stubs.user.misc);

    const userperiod = this.slackbot.robot.brain.data.users[this.stubs.userperiod.id];
    should.equal(userperiod.id, this.stubs.userperiod.id);
    should.equal(userperiod.name, this.stubs.userperiod.name);
    should.equal(userperiod.real_name, this.stubs.userperiod.real_name);
    return should.equal(userperiod.email_address, this.stubs.userperiod.profile.email);
  });

  it('Should merge with user data which is stored by other program', function() {
    const originalUser =
      {something: 'something'};

    this.slackbot.robot.brain.userForId(this.stubs.user.id, originalUser);
    this.slackbot.usersLoaded(null, this.stubs.responseUsersList);

    const user = this.slackbot.robot.brain.data.users[this.stubs.user.id];
    should.equal(user.id, this.stubs.user.id);
    should.equal(user.name, this.stubs.user.name);
    should.equal(user.real_name, this.stubs.user.real_name);
    should.equal(user.email_address, this.stubs.user.profile.email);
    should.equal(user.slack.misc, this.stubs.user.misc);
    return should.equal(user.something, originalUser.something);
  });

  return it('Should detect wrong response from web api', function() {
    this.slackbot.usersLoaded(null, this.stubs.wrongResponseUsersList);
    return should.equal(this.slackbot.robot.brain.data.users[this.stubs.user.id], undefined);
  });
});
