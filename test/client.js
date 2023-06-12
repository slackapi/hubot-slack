
const { describe, it, beforeEach } = require('node:test');
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

const { RtmClient, WebClient } = require('@slack/client');

describe('Init', function() {
  let stubs, slackbox, client;
  beforeEach(function() {
    ({ stubs, slackbot, client } = require('./stubs.js')());
  });
  it('Should initialize with an RTM client', function() {
    assert.ok(client.rtm instanceof RtmClient)
    assert.deepEqual(client.rtm._token, 'xoxb-faketoken');
  });

  it('Should initialize with a Web client', function() {
    assert.ok(client.web instanceof WebClient);
    assert.deepEqual(client.web._token, 'xoxb-faketoken');
  });

});

describe('connect()', () => {
  let stubs, slackbox, client;
  beforeEach(function() {
    ({ stubs, slackbot, client } = require('./stubs.js')());
  });
  it('Should be able to connect', function() {
    client.connect();
    assert.ok(stubs._connected);
  });
});

describe('onEvent()', function() {
  let stubs, slackbox, client;
  beforeEach(function() {
    ({ stubs, slackbot, client } = require('./stubs.js')());
  });
  it('should not need to be set', function() {
    client.rtm.emit('message', { fake: 'message' });
    assert.ok(true);
  });
  it('should emit pre-processed messages to the callback', function(t, done) {
    client.onEvent(message => {
      assert.ok(message);
      assert.deepEqual(message.user?.real_name, stubs.user.real_name);
      assert.deepEqual(message.channel, stubs.channel.id);
      done();
    });
    // the shape of the following object is a raw RTM message event: https://api.slack.com/events/message
    client.rtm.emit('message', {
      type: 'message',
      user: stubs.user.id,
      channel: stubs.channel.id,
      text: 'blah',
      ts: '1355517523.000005'
    });
    assert.deepEqual(stubs.robot.logger.logs.error, undefined);
  });
  it('should successfully convert bot users', function(t, done) {
    client.onEvent(message => {
      assert.ok(message);
      assert.deepEqual(message.user.id, stubs.user.id);
      assert.deepEqual(message.channel, stubs.channel.id);
      done();
    });
    // the shape of the following object is a raw RTM message event: https://api.slack.com/events/message
    client.rtm.emit('message', {
      type: 'message',
      bot_id: 'B123',
      channel: stubs.channel.id,
      text: 'blah'
    });
    assert.deepEqual(stubs.robot.logger.logs.error, undefined);
  });

  it('should handle undefined bot users', function(t, done) {
    client.onEvent(message => {
      assert.ok(message);
      assert.deepEqual(message.channel, stubs.channel.id);
      done();
    });
    client.rtm.emit('message', {
      type: 'message',
      bot_id: 'B789',
      channel: stubs.channel.id,
      text: 'blah'
    });
    assert.deepEqual(stubs.robot.logger.logs.error, undefined);
  });

  it('should handle undefined users as envisioned', function(t, done) {
    client.onEvent(message => {
      assert.ok(message);
      assert.deepEqual(message.channel, stubs.channel.id);
      done();
    });
    client.rtm.emit('message', {
      type: 'message',
      user: undefined,
      channel: stubs.channel.id,
      text: 'eat more veggies'
    });
    assert.deepEqual(stubs.robot.logger.logs.error, undefined);
  });

  it('should update bot id to user representation map', function(t, done) {
    client.onEvent(message => {
      assert.ok(message);
      assert.deepEqual(client.botUserIdMap[stubs.bot.id].id, stubs.user.id);
      done();
    });
    
    // the shape of the following object is a raw RTM message event: https://api.slack.com/events/message
    client.rtm.emit('message', {
      type: 'message',
      bot_id: stubs.bot.id,
      channel: stubs.channel.id,
      text: 'blah'
    });
    assert.deepEqual(stubs.robot.logger.logs.error, undefined);
  });
  it('should use user representation for bot id in map', function(t, done) {
    client.onEvent(message => {
      assert.ok(message);
      assert.deepEqual(message.user.id, stubs.user.id);
      done();
    });
    
    client.botUserIdMap[stubs.bot.id] = stubs.user;
    // the shape of the following object is a raw RTM message event: https://api.slack.com/events/message
    client.rtm.emit('message', {
      type: 'message',
      bot_id: stubs.bot.id,
      channel: stubs.channel.id,
      text: 'blah'
    });
    assert.deepEqual(stubs.robot.logger.logs.error, undefined);
  });
  it('should log an error when expanded info cannot be fetched using the Web API', function(t, done) {
    client.onEvent(message => {
      console.log('throwing error', message)
      throw new Error('A message was emitted');
    });
    client.rtm.emit('message', {
      type: 'message',
      user: 'NOT A USER',
      channel: stubs.channel.id,
      text: 'blah',
      ts: '1355517523.000005'
    });
    // wait for the next tick to check the logs so that the error can be thrown
    // and caught by the test framework. process.nextTick executes the function
    // after everything in the current call stack has been executed.
    process.nextTick(() => {
      if (stubs.robot.logger.logs) {
        console.log(JSON.stringify(stubs.robot.logger.logs))
        assert.deepEqual(stubs.robot.logger.logs?.error?.length, 1);
      }
      done();
    });
  });
  
  it('should use user instead of bot_id', function(t, done) {
    client.onEvent(message => {
      assert.ok(message);
      assert.deepEqual(message.user.id, stubs.user.id);
      done();
    });

    client.botUserIdMap[stubs.bot.id] = stubs.userperiod;
    client.rtm.emit('message', {
      type: 'message',
      bot_id: stubs.bot.id,
      user: stubs.user.id,
      channel: stubs.channel.id,
      text: 'blah'
    });
    assert.deepEqual(stubs.robot.logger.logs.error, undefined);
  });
});

describe('setTopic()', function() {
  let stubs, slackbox, client;
  beforeEach(function() {
    ({ stubs, slackbot, client } = require('./stubs.js')());
  });
  it("Should set the topic in a channel", async function() {
    await client.setTopic(stubs.channel.id, 'iAmTopic');
    assert.deepEqual(stubs._topic, 'iAmTopic');
  });
  it("should not set the topic in a DM", async function() {
    await client.setTopic(stubs.DM.id, 'iAmTopic');
    assert.deepEqual(stubs['_topic'], undefined);
  });
  it("should not set the topic in a MPIM", async function() {
    await client.setTopic(stubs.group.id, 'iAmTopic');
    assert.deepEqual(stubs['_topic'], undefined);
    // NOTE: no good way to assert that debug log was output
  });
  it("should log an error if the setTopic web API method fails", async function() {
    await client.setTopic('NOT A CONVERSATION', 'iAmTopic');
    assert.deepEqual(stubs['_topic'], undefined);
    if (stubs.robot.logger.logs != null) {
      assert.deepEqual(stubs.robot.logger.logs.error.length, 1);
    }
  });
});

describe('send()', function() {
  let stubs, slackbox, client;
  beforeEach(function() {
    ({ stubs, slackbot, client } = require('./stubs.js')());
  });
  it('Should send a plain string message to room', function() {
    client.send({room: 'room1'}, 'Message');
    assert.deepEqual(stubs._msg, 'Message');
    assert.deepEqual(stubs._room, 'room1');
  });

  it('Should send an object message to room', function() {
    client.send({room: 'room2'}, {text: 'textMessage'});
    assert.deepEqual(stubs._msg, 'textMessage');
    assert.deepEqual(stubs._room, 'room2');
  });

  it('Should be able to send a DM to a user object', function() {
    client.send(stubs.user, 'DM Message');
    assert.deepEqual(stubs._dmmsg, 'DM Message');
    assert.deepEqual(stubs._room, stubs.user.id);
  });

  it('should not send a message to a user without an ID', function() {
    client.send({ name: "my_crufty_username" }, "don't program with usernames");
    assert.deepEqual(stubs._sendCount, 0);
  });

  it('should log an error when chat.postMessage fails (plain string)', function(t, done) {
    client.send({ room: stubs.channelWillFailChatPost }, "Message");
    assert.deepEqual(stubs._sendCount, 0);
    return setImmediate(( () => {
      if (stubs.robot.logger.logs != null) {
        assert.deepEqual(stubs.robot.logger.logs.error.length, 1);
      }
      done();
    }
    ), 0);
  });

  it('should log an error when chat.postMessage fails (object)', function(t, done) {
    client.send({ room: stubs.channelWillFailChatPost }, { text: "textMessage" });
    assert.deepEqual(stubs._sendCount, 0);
    return setImmediate(( () => {
      if (stubs.robot.logger.logs != null) {
        assert.deepEqual(stubs.robot.logger.logs.error.length, 1);
      }
      done();
    }
    ), 0);
  });
});

describe('loadUsers()', function() {
  let stubs, slackbox, client;
  beforeEach(function() {
    ({ stubs, slackbot, client } = require('./stubs.js')());
  });
  it('should make successive calls to users.list', function() {
    return client.loadUsers((err, result) => {
      if (stubs != null) {
        assert.deepEqual(stubs._listCount, 2);
      }
      assert.deepEqual(result.members.length, 4);
    });
  });
  it('should handle errors', function() {
    stubs._listError = true;
    return client.loadUsers((err, result) => {
      assert.ok(err instanceof Error);
    });
  });
});

describe('Users data', function() {
  let stubs, slackbox, client;
  beforeEach(function() {
    ({ stubs, slackbot, client } = require('./stubs.js')());
  });
  it('Should add a user data', function() {
    client.updateUserInBrain(stubs.user);
    const user = slackbot.robot.brain.data.users[stubs.user.id];
    assert.deepEqual(user.id, stubs.user.id);
    assert.deepEqual(user.name, stubs.user.name);
    assert.deepEqual(user.real_name, stubs.user.real_name);
    assert.deepEqual(user.email_address, stubs.user.profile.email);
    assert.deepEqual(user.slack.misc, stubs.user.misc);
  });

  it('Should add a user data (user with no profile)', function() {
    client.updateUserInBrain(stubs.usernoprofile);
    const user = slackbot.robot.brain.data.users[stubs.usernoprofile.id];
    assert.deepEqual(user.id, stubs.usernoprofile.id);
    assert.deepEqual(user.name, stubs.usernoprofile.name);
    assert.deepEqual(user.real_name, stubs.usernoprofile.real_name);
    assert.deepEqual(user.slack.misc, stubs.usernoprofile.misc);
    assert.ok(user.email_address == undefined);
  });

  it('Should add a user data (user with no email in profile)', function() {
    client.updateUserInBrain(stubs.usernoemail);

    const user = slackbot.robot.brain.data.users[stubs.usernoemail.id];
    assert.deepEqual(user.id, stubs.usernoemail.id);
    assert.deepEqual(user.name, stubs.usernoemail.name);
    assert.deepEqual(user.real_name, stubs.usernoemail.real_name);
    assert.deepEqual(user.slack.misc, stubs.usernoemail.misc);
    assert.ok(user.email_address == undefined);
  });

  it('Should modify a user data', function() {
    client.updateUserInBrain(stubs.user);

    let user = slackbot.robot.brain.data.users[stubs.user.id];
    assert.deepEqual(user.id, stubs.user.id);
    assert.deepEqual(user.name, stubs.user.name);
    assert.deepEqual(user.real_name, stubs.user.real_name);
    assert.deepEqual(user.email_address, stubs.user.profile.email);
    assert.deepEqual(user.slack.misc, stubs.user.misc);

    const user_change_event = {
      type: 'user_change',
      user: {
        id: stubs.user.id,
        name: 'modified_name',
        real_name: stubs.user.real_name,
        profile: {
          email: stubs.user.profile.email
        }
      }
    };

    client.updateUserInBrain(user_change_event);

    user = slackbot.robot.brain.data.users[stubs.user.id];
    assert.deepEqual(user.id, stubs.user.id);
    assert.deepEqual(user.name, user_change_event.user.name);
    assert.deepEqual(user.real_name, stubs.user.real_name);
    assert.deepEqual(user.email_address, stubs.user.profile.email);
    assert.deepEqual(user.slack.misc, undefined);
    assert.deepEqual(user.slack.client, undefined);
  });
});

describe('fetchBotUser()', function() {
  let stubs, slackbox, client;
  beforeEach(function() {
    ({ stubs, slackbot, client } = require('./stubs.js')());
  });
  it('should return user representation from map', async function() {
    const {
      user
    } = stubs;
    client.botUserIdMap[stubs.bot.id] = user;
    const res = await client.fetchBotUser(stubs.bot.id)
    assert.deepEqual(res.id, user.id);
  });

  it('should return constant data if id is slackbots id', async function() {
    const user = stubs.slack_bot;
    const res = await client.fetchBotUser(stubs.slack_bot.id)
    assert.deepEqual(res.id, user.id);
    assert.deepEqual(res.user_id, user.user_id);
  });
});

describe('fetchUser()', function() {
  let stubs, slackbox, client;
  beforeEach(function() {
    ({ stubs, slackbot, client } = require('./stubs.js')());
  });
  it('should return user representation from brain', async function() {
    const {
      user
    } = stubs;
    client.updateUserInBrain(user);
    const res = await client.fetchUser(user.id)
    assert.deepEqual(res.id, user.id);
  });
  
  it('Should sync interacting users when syncing disabled', async function() {
    slackbot.options.disableUserSync = true;
    slackbot.run();

    const res = await client.fetchUser(stubs.user.id)
    assert.ok(Object.keys(slackbot.robot.brain.data.users).includes('U123'));
  });
});

describe('fetchConversation()', function() {
  let stubs, slackbox, client;
  beforeEach(function() {
    ({ stubs, slackbot, client } = require('./stubs.js')());
  });
  it('Should remove expired conversation info', async function() {
    const {
      channel
    } = stubs;
    client.channelData[channel.id] = {
      channel: {id: 'C123', name: 'foo'},
      updated: stubs.expired_timestamp
    };
    const res = await client.fetchConversation(channel.id)
    assert.deepEqual(res.name, channel.name);
    assert.ok(Object.keys(client.channelData).includes('C123'));
    assert.deepEqual(client.channelData['C123'].channel.name, channel.name);
  });
  it('Should return conversation info if not expired', async function() {
    const {
      channel
    } = stubs;
    client.channelData[channel.id] = {
      channel: {id: 'C123', name: 'foo'},
      updated: Date.now()
    };
    const res = await client.fetchConversation(channel.id)
    assert.deepEqual(res.id, channel.id);
    assert.ok(Object.keys(client.channelData).includes('C123'));
    assert.deepEqual(client.channelData['C123'].channel.name, 'foo');
  });
});
