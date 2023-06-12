const {describe, it, beforeEach, before, after} = require('node:test');
const assert = require('node:assert/strict');
const Module = require('module');

const hookModuleToReturnMockFromRequire = (module, mock) => {
  const originalRequire = Module.prototype.require;
  Module.prototype.require = function() {
    if (arguments[0] === module) {
      return mock;
    }
    return originalRequire.apply(this, arguments);
  };
};


const hubotSlackMock = require('../slack.js');
hookModuleToReturnMockFromRequire('hubot-slack', hubotSlackMock);

const { loadBot } = require.main.require('hubot');
const { SlackTextMessage, ReactionMessage, PresenceMessage, FileSharedMessage } = require('../src/message');

describe('Adapter', function() {
  let stubs, slackbot;
  beforeEach(function() {
    ({stubs, slackbot} = require('./stubs.js')());
  });
    
  it('Should initialize with a robot', function() {
    assert.deepEqual(slackbot.robot, stubs.robot);
  });

  it('Should load an instance of Robot with extended methods', async function() {
    const loadedRobot = loadBot('slack', false, 'Hubot');
    await loadedRobot.loadAdapter();    
    // Check to make sure presenceChange and react are loaded to Robot
    assert.ok(loadedRobot.presenceChange instanceof Function);
    assert.deepEqual(loadedRobot.presenceChange.length, 3);
    assert.ok(loadedRobot.hearReaction instanceof Function);
    assert.deepEqual(loadedRobot.hearReaction.length, 3);
    assert.ok(loadedRobot.fileShared instanceof Function);
    assert.deepEqual(loadedRobot.fileShared.length, 3);
  });
});

describe('Connect', () => {
  let stubs, slackbot;
  beforeEach(function() {
    ({stubs, slackbot} = require('./stubs.js')());
  });

  it('Should connect successfully', function() {
    slackbot.run();
    assert.ok(stubs._connected);
  })
});

describe('Authenticate', () => {
  let stubs, slackbot;
  beforeEach(function() {
    ({stubs, slackbot} = require('./stubs.js')());
  });

  it('Should authenticate successfully', function() {
    const {logger} = slackbot.robot;
    const start = { self: {
      id: stubs.self.id,
      name: stubs.self.name
    },
    team: {
      id: stubs.team.id,
      name: stubs.team.name
    },
    users: [
      stubs.self,
      stubs.user
    ]
  };

    slackbot.authenticated(start);
    assert.deepEqual(slackbot.self.id, stubs.self.id);
    assert.deepEqual(slackbot.robot.name, stubs.self.name);
    assert.ok(logger.logs["info"].length > 0)
    assert.deepEqual(logger.logs["info"][logger.logs["info"].length-1], `Logged in as @${stubs.self.name} in workspace ${stubs.team.name}`);
  });
});

describe('Logger', function() {
  let stubs, slackbot;
  beforeEach(function() {
    ({stubs, slackbot} = require('./stubs.js')());
  });

  it('It should log missing token error', function() {
    const {logger} = slackbot.robot;
    slackbot.options.token = null;
    slackbot.run();
    assert.ok(logger.logs["error"].length > 0);
    assert.deepEqual(logger.logs["error"][logger.logs["error"].length-1], 'No token provided to Hubot');
  });

  it('It should log invalid token error', function() {
    const {logger} = slackbot.robot;
    slackbot.options.token = "ABC123";
    slackbot.run() -
    assert.ok(logger.logs["error"].length > 0);
    assert.deepEqual(logger.logs["error"][logger.logs["error"].length-1], 'Invalid token provided, please follow the upgrade instructions');
  });
});

describe('Disable Sync', function() {
  let slackbot;
  beforeEach(function() {
    ({stubs, slackbot} = require('./stubs.js')());
  });

  it('Should sync users by default', function() {
    slackbot.run();
    assert.deepEqual(Object.keys(slackbot.robot.brain.data.users), ['1','2','3','4']);
  });

  it('Should not sync users when disabled', function() {
    slackbot.options.disableUserSync = true;
    slackbot.run();
    assert.deepEqual(Object.keys(slackbot.robot.brain.data.users).length, 0);
  });
});

describe('Send Messages', function() {
  let stubs, slackbot;
  beforeEach(function() {
    ({stubs, slackbot} = require('./stubs.js')());
  });

  it('Should send a message', function() {
    slackbot.send({room: stubs.channel.id}, 'message');
    assert.deepEqual(stubs._sendCount, 1);
    assert.deepEqual(stubs._msg, 'message');
  });

  it('Should send multiple messages', function() {
    slackbot.send({room: stubs.channel.id}, 'one', 'two', 'three');
    assert.deepEqual(stubs._sendCount, 3);
  });

  it('Should not send empty messages', function() {
    slackbot.send({room: stubs.channel.id}, 'Hello', '', '', 'world!');
    assert.deepEqual(stubs._sendCount, 2);
  });

  it('Should not fail for inexistant user', function() {
    assert.doesNotThrow(() => slackbot.send({room: 'U987'}, 'Hello'));
  });

  it('Should open a DM channel if needed', function() {
    const msg = 'Test';
    slackbot.send({room: stubs.user.id}, msg);
    assert.deepEqual(stubs._dmmsg, msg);
  });

  it('Should send a message to a user', function() {
    slackbot.send(stubs.user, 'message');
    assert.deepEqual(stubs._dmmsg, 'message');
    assert.deepEqual(stubs._room, stubs.user.id);
  });

  it('Should send a message with a callback', function(t, done) {
    slackbot.send({room: stubs.channel.id}, 'message with a callback', function() {
      assert.ok(true);
      done();
    });
    assert.deepEqual(stubs._sendCount, 1);
    assert.deepEqual(stubs._msg, 'message with a callback');
  });
});

describe('Client sending message', function() {
  let stubs, client;
  beforeEach(function() {
    ({stubs, client} = require('./stubs.js')());
  });

  it('Should append as_user = true', function() {
    client.send({room: stubs.channel.id}, {text: 'foo', user: stubs.user, channel: stubs.channel.id});
    assert.ok(stubs._opts.as_user);
  });

  it('Should append as_user = true only as a default', function() {
    client.send({room: stubs.channel.id}, {text: 'foo', user: stubs.user, channel: stubs.channel.id, as_user: false});
    assert.deepEqual(stubs._opts.as_user, true);
  });
});

describe('Reply to Messages', function() {
  let stubs, slackbot;
  beforeEach(function() {
    ({stubs, slackbot} = require('./stubs.js')());
  });

  it('Should mention the user in a reply sent in a channel', function() {
    slackbot.reply({user: stubs.user, room: stubs.channel.id}, 'message');
    assert.deepEqual(stubs._sendCount, 1);
    assert.deepEqual(stubs._msg, `<@${stubs.user.id}>: message`);
  });

  it('Should mention the user in multiple replies sent in a channel', function() {
    slackbot.reply({user: stubs.user, room: stubs.channel.id}, 'one', 'two', 'three');
    assert.deepEqual(stubs._sendCount, 3);
    assert.deepEqual(stubs._msg, `<@${stubs.user.id}>: three`);
  });

  it('Should send nothing if messages are empty', function() {
    slackbot.reply({user: stubs.user, room: stubs.channel.id}, '');
    assert.deepEqual(stubs._sendCount, 0);
  });

  it('Should NOT mention the user in a reply sent in a DM', function() {
    slackbot.reply({user: stubs.user, room: stubs.DM.id }, 'message');
    assert.deepEqual(stubs._sendCount, 1);
    assert.deepEqual(stubs._dmmsg, 'message');
  });

  it('Should call the callback', function(t, done) {
    slackbot.reply({user: stubs.user, room: stubs.channel.id}, 'message', function() {
      assert.ok(true);
      done();
    });
    assert.deepEqual(stubs._sendCount, 1);
    assert.deepEqual(stubs._msg, `<@${stubs.user.id}>: message`);
  });
});

describe('Setting the channel topic', function() {
  let stubs, slackbot;
  beforeEach(function() {
    ({stubs, slackbot} = require('./stubs.js')());
  });

  it('Should set the topic in channels', function(t, done) {
    stubs.receiveMock.onTopic = function(topic) {
      assert.deepEqual(topic, 'channel');
      done();
    };
    slackbot.setTopic({room: stubs.channel.id}, 'channel');
  });

  it('Should NOT set the topic in DMs', function() {
    slackbot.setTopic({room: 'D1232'}, 'DM');
    assert.equal(stubs._topic, undefined);
  });
});

describe('Receiving an error event', function() {
  let slackbot;
  beforeEach(function() {
    ({slackbot} = require('./stubs.js')());
  });
  it('Should propagate that error', function() {
    hit = false;
    slackbot.robot.on('error', error => {
      assert.deepEqual(error.msg, 'ohno');
      hit = true;
    });
    assert.ok(!hit);
    slackbot.error({msg: 'ohno', code: -2});
    assert.ok(hit);
  });

  it('Should handle rate limit errors', function() {
    const {logger} = slackbot.robot;
    slackbot.error({msg: 'ratelimit', code: -1});
    assert.ok(logger.logs["error"].length > 0);
  });
});

describe('Handling incoming messages', function() {
  let stubs, slackbot;
  beforeEach(function() {
    ({stubs, slackbot} = require('./stubs.js')());
  });

  it('Should handle regular messages as hoped and dreamed', function(t, done) {
    stubs.receiveMock.onReceived = function(msg) {
      assert.deepEqual(msg.text, 'foo');
      done();
    };
    slackbot.eventHandler({type: 'message', text: 'foo', user: stubs.user, channel: stubs.channel.id });
  });

  it('Should handle broadcasted messages', function(t, done) {
    stubs.receiveMock.onReceived = function(msg) {
      assert.deepEqual(msg.text, 'foo');
      done();
    };
    slackbot.eventHandler({type: 'message', text: 'foo', subtype: 'thread_broadcast', user: stubs.user, channel: stubs.channel.id });
  });

  it('Should prepend our name to a name-lacking message addressed to us in a DM', function(t, done) {
    const bot_name = slackbot.robot.name;
    stubs.receiveMock.onReceived = function(msg) {
      assert.deepEqual(msg.text, `${bot_name} foo`);
      done();
    };
    slackbot.eventHandler({type: 'message', text: "foo", user: stubs.user, channel: stubs.DM.id});
  });

  it('Should NOT prepend our name to a name-containing message addressed to us in a DM', function(t, done) {
    const bot_name = slackbot.robot.name;
    stubs.receiveMock.onReceived = function(msg) {
      assert.deepEqual(msg.text, `${bot_name} foo`);
      done();
    };
    slackbot.eventHandler({type: 'message', text: `${bot_name} foo`, user: stubs.user, channel: stubs.DM.id});
  });

  it('Should return a message object with raw text and message', function(t, done) {
    //the shape of this data is an RTM message event passed through SlackClient#messageWrapper
    //see: https://api.slack.com/events/message
    const messageData = {
      type: 'message',
      user: stubs.user,
      channel: stubs.channel.id,
      text: 'foo <http://www.example.com> bar',
    };
    stubs.receiveMock.onReceived = function(msg) {
      assert.deepEqual((msg instanceof SlackTextMessage), true);
      assert.deepEqual(msg.text, "foo http://www.example.com bar");
      assert.deepEqual(msg.rawText, "foo <http://www.example.com> bar");
      assert.deepEqual(msg.rawMessage, messageData);
      done();
    };
    slackbot.eventHandler(messageData);
  });

  it('Should handle member_joined_channel events as envisioned', function() {
    slackbot.eventHandler({
      type: 'member_joined_channel',
      user: stubs.user,
      channel: stubs.channel.id,
      ts: stubs.event_timestamp
    });
    assert.deepEqual(stubs._received.constructor.name, "EnterMessage");
    assert.deepEqual(stubs._received.ts, stubs.event_timestamp);
    assert.deepEqual(stubs._received.user.id, stubs.user.id);
  });

  it('Should handle member_left_channel events as envisioned', function() {
    slackbot.eventHandler({
      type: 'member_left_channel',
      user: stubs.user,
      channel: stubs.channel.id,
      ts: stubs.event_timestamp
    });
    assert.deepEqual(stubs._received.constructor.name, "LeaveMessage");
    assert.deepEqual(stubs._received.ts, stubs.event_timestamp);
    assert.deepEqual(stubs._received.user.id, stubs.user.id);
  });

  it('Should handle channel_topic events as envisioned', function() {
    slackbot.eventHandler({type: 'message', subtype: 'channel_topic', user: stubs.user, channel: stubs.channel.id});
    assert.deepEqual(stubs._received.constructor.name, "TopicMessage");
    assert.deepEqual(stubs._received.user.id, stubs.user.id);
  });

  it('Should handle group_topic events as envisioned', function() {
    slackbot.eventHandler({type: 'message', subtype: 'group_topic', user: stubs.user, channel: stubs.channel.id});
    assert.deepEqual(stubs._received.constructor.name, "TopicMessage");
    assert.deepEqual(stubs._received.user.id, stubs.user.id);
  });

  it('Should handle reaction_added events as envisioned', function() {
    const reactionMessage = {
      type: 'reaction_added', user: stubs.user, item_user: stubs.self,
      item: { type: 'message', channel: stubs.channel.id, ts: '1360782804.083113'
      },
      reaction: 'thumbsup', event_ts: '1360782804.083113'
    };
    slackbot.eventHandler(reactionMessage);
    assert.deepEqual((stubs._received instanceof ReactionMessage), true);
    assert.deepEqual(stubs._received.user.id, stubs.user.id);
    assert.deepEqual(stubs._received.user.room, stubs.channel.id);
    assert.deepEqual(stubs._received.item_user.id, stubs.self.id);
    assert.deepEqual(stubs._received.type, 'added');
    assert.deepEqual(stubs._received.reaction, 'thumbsup');
  });

  it('Should handle reaction_removed events as envisioned', function() {
    const reactionMessage = {
      type: 'reaction_removed', user: stubs.user, item_user: stubs.self,
      item: { type: 'message', channel: stubs.channel.id, ts: '1360782804.083113'
      },
      reaction: 'thumbsup', event_ts: '1360782804.083113'
    };
    slackbot.eventHandler(reactionMessage);
    assert.deepEqual((stubs._received instanceof ReactionMessage), true);
    assert.deepEqual(stubs._received.user.id, stubs.user.id);
    assert.deepEqual(stubs._received.user.room, stubs.channel.id);
    assert.deepEqual(stubs._received.item_user.id, stubs.self.id);
    assert.deepEqual(stubs._received.type, 'removed');
    assert.deepEqual(stubs._received.reaction, 'thumbsup');
  });

  it('Should not crash with bot messages', function(t, done) {
    stubs.receiveMock.onReceived = function(msg) {
      assert.deepEqual((msg instanceof SlackTextMessage), true);
      done();
    };
    slackbot.eventHandler({type: 'message', subtype: 'bot_message', user: stubs.user, channel: stubs.channel.id, text: 'Pushing is the answer', returnRawText: true });
  });

  it('Should handle single user presence_change events as envisioned', function() {
    slackbot.robot.brain.userForId(stubs.user.id, stubs.user);
    const presenceMessage = {
      type: 'presence_change', user: stubs.user, presence: 'away'
    };
    slackbot.eventHandler(presenceMessage);
    assert.deepEqual((stubs._received instanceof PresenceMessage), true);
    assert.deepEqual(stubs._received.users[0].id, stubs.user.id);
    assert.deepEqual(stubs._received.users.length, 1);
  });

  it('Should handle presence_change events as envisioned', function() {
    slackbot.robot.brain.userForId(stubs.user.id, stubs.user);
    const presenceMessage = {
      type: 'presence_change', users: [stubs.user], presence: 'away'
    };
    slackbot.eventHandler(presenceMessage);
    assert.deepEqual((stubs._received instanceof PresenceMessage), true);
    assert.deepEqual(stubs._received.users[0].id, stubs.user.id);
    assert.deepEqual(stubs._received.users.length, 1);
  });

  it('Should ignore messages it sent itself', function() {
    slackbot.eventHandler({type: 'message', subtype: 'bot_message', user: stubs.self, channel: stubs.channel.id, text: 'Ignore me' });
    assert.deepEqual(stubs._received, undefined);
  });

  it('Should ignore reaction events that it generated itself', function() {
    const reactionMessage = { type: 'reaction_removed', user: stubs.self, reaction: 'thumbsup', event_ts: '1360782804.083113' };
    slackbot.eventHandler(reactionMessage);
    assert.deepEqual(stubs._received, undefined);
  });

  it('Should handle empty users as envisioned', function(t, done){
    stubs.receiveMock.onReceived = function(msg) {
      assert.deepEqual((msg instanceof SlackTextMessage), true);
      done();
    };
    slackbot.eventHandler({type: 'message', subtype: 'bot_message', user: {}, channel: stubs.channel.id, text: 'Foo'});
  });

  it('Should handle reaction events from users who are in different workspace in shared channel', function() {
    const reactionMessage = {
      type: 'reaction_added', user: stubs.org_user_not_in_workspace_in_channel, item_user: stubs.self,
      item: { type: 'message', channel: stubs.channel.id, ts: '1360782804.083113'
      },
      reaction: 'thumbsup', event_ts: '1360782804.083113'
    };

    slackbot.eventHandler(reactionMessage);
    assert.deepEqual((stubs._received instanceof ReactionMessage), true);
    assert.deepEqual(stubs._received.user.id, stubs.org_user_not_in_workspace_in_channel.id);
    assert.deepEqual(stubs._received.user.room, stubs.channel.id);
    assert.deepEqual(stubs._received.item_user.id, stubs.self.id);
    assert.deepEqual(stubs._received.type, 'added');
    assert.deepEqual(stubs._received.reaction, 'thumbsup');
  });
    
  it('Should handle file_shared events as envisioned', function() {
    const fileMessage = {
      type: 'file_shared', user: stubs.user,
      file_id: 'F2147483862', event_ts: '1360782804.083113'
    };
    slackbot.eventHandler(fileMessage);
    assert.deepEqual((stubs._received instanceof FileSharedMessage), true);
    assert.deepEqual(stubs._received.user.id, stubs.user.id);
    assert.deepEqual(stubs._received.file_id, 'F2147483862');
  });
});
    
describe('Robot.fileShared', function() {
  let stubs, slackbot, fileSharedMessage;
  const handleFileShared = msg => `${msg.file_id} shared`;

  beforeEach(function() {
    ({stubs, slackbot} = require('./stubs.js')());
    const user = { id: stubs.user.id, room: stubs.channel.id };
    fileSharedMessage = new FileSharedMessage(user, "F2147483862", '1360782804.083113');
  });

  it('Should register a Listener with callback only', function() {
    slackbot.robot.fileShared(handleFileShared);
    const listener = slackbot.robot.listeners.shift();
    assert.ok(listener.matcher(fileSharedMessage));
    assert.deepEqual(listener.options, {id: null});
    assert.deepEqual(listener.callback(fileSharedMessage), 'F2147483862 shared');
  });
    
  it('Should register a Listener with opts and callback', function() {
    slackbot.robot.fileShared({id: 'foobar'}, handleFileShared);
    const listener = slackbot.robot.listeners.shift();
    assert.ok(listener.matcher(fileSharedMessage));
    assert.deepEqual(listener.options, {id: 'foobar'});
    assert.deepEqual(listener.callback(fileSharedMessage), 'F2147483862 shared');
  });

  it('Should register a Listener with matcher and callback', function() {
    const matcher = msg => msg.file_id === 'F2147483862';
    slackbot.robot.fileShared(matcher, handleFileShared);
    const listener = slackbot.robot.listeners.shift();
    assert.ok(listener.matcher(fileSharedMessage));
    assert.deepEqual(listener.options, {id: null});
    assert.deepEqual(listener.callback(fileSharedMessage), 'F2147483862 shared');
  });

  it('Should register a Listener with matcher, opts, and callback', function() {
    const matcher = msg => msg.file_id === 'F2147483862';
    slackbot.robot.fileShared(matcher, {id: 'foobar'}, handleFileShared);
    const listener = slackbot.robot.listeners.shift();
    assert.ok(listener.matcher(fileSharedMessage));
    assert.deepEqual(listener.options, {id: 'foobar'});
    assert.deepEqual(listener.callback(fileSharedMessage), 'F2147483862 shared');
  });

  it('Should register a Listener that does not match the ReactionMessage', function() {
    const matcher = msg => msg.file_id === 'J12387ALDFK';
    slackbot.robot.fileShared(matcher, handleFileShared);
    const listener = slackbot.robot.listeners.shift();
    assert.ok(!listener.matcher(fileSharedMessage));
  });
});

describe('Robot.hearReaction', function() {
  let stubs, slackbot, reactionMessage;
  const handleReaction = msg => `${msg.reaction} handled`;
  beforeEach(function() {
    ({stubs, slackbot} = require('./stubs.js')());
    const user = { id: stubs.user.id, room: stubs.channel.id };
    const item = {
      type: 'message', channel: stubs.channel.id, ts: '1360782804.083113'
    };
    reactionMessage = new ReactionMessage(
      'reaction_added', user, 'thumbsup', item, '1360782804.083113'
    );
  });

  it('Should register a Listener with callback only', function() {
    slackbot.robot.hearReaction(handleReaction);
    const listener = slackbot.robot.listeners.shift();
    assert.ok(listener.matcher(reactionMessage));
    assert.deepEqual(listener.options, {id: null});
    assert.deepEqual(listener.callback(reactionMessage), 'thumbsup handled');
  });

  it('Should register a Listener with opts and callback', function() {
    slackbot.robot.hearReaction({id: 'foobar'}, handleReaction);
    const listener = slackbot.robot.listeners.shift();
    assert.ok(listener.matcher(reactionMessage));
    assert.deepEqual(listener.options, {id: 'foobar'});
    assert.deepEqual(listener.callback(reactionMessage), 'thumbsup handled');
  });

  it('Should register a Listener with matcher and callback', function() {
    const matcher = msg => msg.type === 'added';
    slackbot.robot.hearReaction(matcher, handleReaction);
    const listener = slackbot.robot.listeners.shift();
    assert.ok(listener.matcher(reactionMessage));
    assert.deepEqual(listener.options, {id: null});
    assert.deepEqual(listener.callback(reactionMessage), 'thumbsup handled');
  });

  it('Should register a Listener with matcher, opts, and callback', function() {
    const matcher = msg => (msg.type === 'removed') || (msg.reaction === 'thumbsup');
    slackbot.robot.hearReaction(matcher, {id: 'foobar'}, handleReaction);
    const listener = slackbot.robot.listeners.shift();
    assert.ok(listener.matcher(reactionMessage));
    assert.deepEqual(listener.options, {id: 'foobar'});
    assert.deepEqual(listener.callback(reactionMessage), 'thumbsup handled');
  });

  it('Should register a Listener that does not match the ReactionMessage', function() {
    const matcher = msg => msg.type === 'removed';
    slackbot.robot.hearReaction(matcher, handleReaction);
    const listener = slackbot.robot.listeners.shift();
    assert.ok(!listener.matcher(reactionMessage));
  });
});

describe('Users data', function() {
  let stubs, slackbot;
  beforeEach(function() {
    ({stubs, slackbot} = require('./stubs.js')());
  });
  it('Should load users data from web api', function() {
    slackbot.usersLoaded(null, stubs.responseUsersList);

    const user = slackbot.robot.brain.data.users[stubs.user.id];
    assert.deepEqual(user.id, stubs.user.id);
    assert.deepEqual(user.name, stubs.user.name);
    assert.deepEqual(user.real_name, stubs.user.real_name);
    assert.deepEqual(user.email_address, stubs.user.profile.email);
    assert.deepEqual(user.slack.misc, stubs.user.misc);

    const userperiod = slackbot.robot.brain.data.users[stubs.userperiod.id];
    assert.deepEqual(userperiod.id, stubs.userperiod.id);
    assert.deepEqual(userperiod.name, stubs.userperiod.name);
    assert.deepEqual(userperiod.real_name, stubs.userperiod.real_name);
    assert.deepEqual(userperiod.email_address, stubs.userperiod.profile.email);
  });

  it('Should merge with user data which is stored by other program', function() {
    const originalUser =
      {something: 'something'};

    slackbot.robot.brain.userForId(stubs.user.id, originalUser);
    slackbot.usersLoaded(null, stubs.responseUsersList);

    const user = slackbot.robot.brain.data.users[stubs.user.id];
    assert.deepEqual(user.id, stubs.user.id);
    assert.deepEqual(user.name, stubs.user.name);
    assert.deepEqual(user.real_name, stubs.user.real_name);
    assert.deepEqual(user.email_address, stubs.user.profile.email);
    assert.deepEqual(user.slack.misc, stubs.user.misc);
    assert.deepEqual(user.something, originalUser.something);
  });

  it('Should detect wrong response from web api', function() {
    slackbot.usersLoaded(null, stubs.wrongResponseUsersList);
    assert.deepEqual(slackbot.robot.brain.data.users[stubs.user.id], undefined);
  });
});
