const {describe, it, beforeEach, before, after} = require('node:test');
const assert = require('node:assert/strict');
const Module = require('module');
const SlackBot = require('../src/bot.js');

const hookModuleToReturnMockFromRequire = (module, mock) => {
  const originalRequire = Module.prototype.require;
  Module.prototype.require = function() {
    if (arguments[0] === module) {
      return mock;
    }
    return originalRequire.apply(this, arguments);
  };
};

const hubotSlackMock = require('../index.js');
hookModuleToReturnMockFromRequire('hubot-slack', hubotSlackMock);

const { loadBot } = require.main.require('hubot');
const { SlackTextMessage, ReactionMessage, FileSharedMessage } = require('../src/message');
const { env } = require('node:process');

describe('Adapter', function() {
  let stubs, slackbot;
  beforeEach(function() {
    ({stubs, slackbot} = require('./stubs.js')());
  });
    
  it('Should initialize with a robot', function() {
    assert.deepEqual(slackbot.robot, stubs.robot);
  });

  it('Should load an instance of Robot with extended methods', async function() {
    process.env.HUBOT_SLACK_APP_TOKEN = 'xapp-faketoken';
    process.env.HUBOT_SLACK_BOT_TOKEN = 'xoxb-faketoken';

    const loadedRobot = loadBot('hubot-slack', false, 'Hubot');
    await loadedRobot.loadAdapter();    

    assert.ok(loadedRobot.hearReaction instanceof Function);
    assert.deepEqual(loadedRobot.hearReaction.length, 3);
    assert.ok(loadedRobot.fileShared instanceof Function);
    assert.deepEqual(loadedRobot.fileShared.length, 3);
    delete process.env.HUBOT_SLACK_APP_TOKEN;
    delete process.env.HUBOT_SLACK_BOT_TOKEN;
  });
});

describe('Connect', () => {
  let stubs, slackbot;
  beforeEach(function() {
    ({stubs, slackbot} = require('./stubs.js')());
  });

  it('Should connect successfully', (t, done) => {
    slackbot.on('connected', () => {
      assert.ok(true);
      done();
    });
    slackbot.run();
  })
});

describe('Authenticate', () => {
  let stubs, slackbot;
  beforeEach(function() {
    ({stubs, slackbot} = require('./stubs.js')());
  });

  it('Should authenticate successfully', async () => {
    const {logger} = slackbot.robot;
    const start = {
      self: {
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

    await slackbot.authenticated(start);
    assert.deepEqual(slackbot.self.id, stubs.self.id);
    assert.deepEqual(slackbot.robot.name, stubs.self.name);
    assert.ok(logger.logs["info"].length > 0)
  });
});

describe('Logger', function() {
  let stubs, slackbot;
  beforeEach(function() {
    ({stubs, slackbot} = require('./stubs.js')());
  });

  it('It should log invalid botToken error', (t, done) => {
    const {logger} = slackbot.robot;
    logger.error = message => {
      assert.deepEqual(message, 'Invalid botToken provided, please follow the upgrade instructions');
      done();
    }
    slackbot.options.appToken = "xapp-faketoken";
    slackbot.options.botToken = "ABC123";
    slackbot.run();
  });

  it('It should log invalid appToken error', (t, done) => {
    const {logger} = slackbot.robot;
    logger.error = message => {
      assert.deepEqual(message, 'Invalid appToken provided, please follow the upgrade instructions');
      done();
    }
    slackbot.options.appToken = "ABC123";
    slackbot.options.botToken = "xoxb-faketoken";
    slackbot.run();
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
    slackbot.client.send = (envelope, message) => {
      stubs._sendCount++;
      stubs._msg = message;
    };
    slackbot.send({room: stubs.channel.id}, 'message');
    assert.deepEqual(stubs._sendCount, 1);
    assert.deepEqual(stubs._msg, 'message');
  });

  it('Should send multiple messages', function() {
    slackbot.client.send = (envelope, message) => {
      stubs._sendCount++;
    };

    slackbot.send({room: stubs.channel.id}, 'one', 'two', 'three');
    assert.deepEqual(stubs._sendCount, 3);
  });

  it('Should not send empty messages', function() {
    slackbot.client.send = (envelope, message) => {
      stubs._sendCount++;
    };
    slackbot.send({room: stubs.channel.id}, 'Hello', '', '', 'world!');
    assert.deepEqual(stubs._sendCount, 2);
  });

  it('Should not fail for inexistant user', function() {
    assert.doesNotThrow(() => slackbot.send({room: 'U987'}, 'Hello'));
  });

  it('Should open a DM channel if needed', function() {
    const msg = 'Test';
    slackbot.client.send = (envelope, message) => {
      stubs._dmmsg = message;
    };
    slackbot.send({room: stubs.user.id}, msg);
    assert.deepEqual(stubs._dmmsg, msg);
  });

  it('Should send a message to a user', function() {
    slackbot.client.send = (envelope, message) => {
      stubs._dmmsg = message;
      stubs._room = envelope.room;
    };
    slackbot.send({room: stubs.user.id}, 'message');
    assert.deepEqual(stubs._dmmsg, 'message');
    assert.deepEqual(stubs._room, stubs.user.id);
  });

  it('Should send a message with a callback', function(t, done) {
    slackbot.client.send = (envelope, message) => {
      stubs._msg = message;
      stubs._sendCount++;
    };
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
    slackbot.client.send = (envelope, message) => {
      stubs._sendCount++;
      stubs._msg = message;
    };
    slackbot.reply({user: stubs.user, room: stubs.channel.id}, 'message');
    assert.deepEqual(stubs._sendCount, 1);
    assert.deepEqual(stubs._msg, `<@${stubs.user.id}>: message`);
  });

  it('Should mention the user in multiple replies sent in a channel', function() {
    slackbot.client.send = (envelope, message) => {
      stubs._sendCount++;
      stubs._msg = message;
    };
    slackbot.reply({user: stubs.user, room: stubs.channel.id}, 'one', 'two', 'three');
    assert.deepEqual(stubs._sendCount, 3);
    assert.deepEqual(stubs._msg, `<@${stubs.user.id}>: three`);
  });

  it('Should send nothing if messages are empty', function() {
    slackbot.client.send = (envelope, message) => {
      stubs._sendCount++;
      stubs._msg = message;
    };
    slackbot.reply({user: stubs.user, room: stubs.channel.id}, '');
    assert.deepEqual(stubs._sendCount, 0);
  });

  it('Should NOT mention the user in a reply sent in a DM', function() {
    slackbot.client.send = (envelope, message) => {
      stubs._sendCount++;
      stubs._dmmsg = message;
    };
    slackbot.reply({user: stubs.user, room: stubs.DM.id }, 'message');
    assert.deepEqual(stubs._sendCount, 1);
    assert.deepEqual(stubs._dmmsg, 'message');
  });

  it('Should call the callback', function(t, done) {
    slackbot.client.send = (envelope, message) => {
      stubs._sendCount++;
      stubs._msg = message;
    };
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
    slackbot.eventHandler({body: { event: { text: 'foo', type: 'message', user: stubs.user.id }}, event: { text: 'foo', type: 'message', user: stubs.user.id, channel: stubs.channel.id }});
  });

  it('Should prepend our name to a name-lacking message addressed to us in a DM', function(t, done) {
    const bot_name = slackbot.robot.name;
    stubs.receiveMock.onReceived = function(msg) {
      assert.deepEqual(msg.text, `@${bot_name} foo`);
      done();
    };
    slackbot.eventHandler({body: { event: { text: 'foo', type: 'message', user: stubs.user.id, channel_type: 'im' }}, event: { text: 'foo', type: 'message', user: stubs.user.id, channel_type: 'im', channel:stubs.DM.id }});
  });

  it('Should preprend our alias to a name-lacking message addressed to us in a DM', function(t, done) {
   const bot = new SlackBot({alias: '!', logger: {info(){}, debug(){}}}, {appToken: ''});
   bot.self = {
    user_id: '1234'
   }
   const text = bot.replaceBotIdWithName({
      text: '<@1234> foo',
   })
    assert.deepEqual(text, '! foo');
    done()
  });

  it('Should NOT prepend our name to a name-containing message addressed to us in a DM', function(t, done) {
    const bot_name = slackbot.robot.name;
    stubs.receiveMock.onReceived = function(msg) {
      assert.deepEqual(msg.text, `@${bot_name} foo`);
      done();
    };
    slackbot.eventHandler({body: { event: { text: `@${bot_name} foo`, type: 'message', user: stubs.user.id }}, event: { text: 'foo', type: 'message', user: stubs.user.id, channel:stubs.DM.id }});
  });

  it('Should return a message object with raw text and message', function(t, done) {
    //the shape of this data is an RTM message event passed through SlackClient#messageWrapper
    //see: https://api.slack.com/events/message
    const messageData = {
      body: {
        event: {
          type: 'message',
          text: 'foo <http://www.example.com> bar',
          user: stubs.user.id,
          channel: stubs.channel.id,
        }
      },
      event: {
        type: 'message',
        text: 'foo <http://www.example.com> bar',
        user: stubs.user.id,
        channel: stubs.channel.id,
      }
    };
    stubs.receiveMock.onReceived = function(msg) {
      assert.deepEqual((msg instanceof SlackTextMessage), true);
      assert.deepEqual(msg.text, "foo http://www.example.com bar");
      assert.deepEqual(msg.rawText, "foo <http://www.example.com> bar");
      assert.deepEqual(msg.rawMessage, messageData.event);
      done();
    };
    slackbot.eventHandler(messageData);
  });

  it('Should handle member_joined_channel events as envisioned', function() {
    stubs.receiveMock.onReceived = function(msg) {
      assert.deepEqual(msg.constructor.name, "EnterMessage");
      assert.deepEqual(msg.ts, stubs.event_timestamp);
      assert.deepEqual(msg.user.id, stubs.user.id);
      done();
    };
    slackbot.eventHandler({
      body: {
        event: {
          type: 'member_joined_channel',
          user: stubs.user.id,
          channel: stubs.channel.id,
          ts: stubs.event_timestamp
        }
      },
      event: {
        type: 'member_joined_channel',
        user: stubs.user.id,
        channel: stubs.channel.id,
        ts: stubs.event_timestamp
      }
    });
  });

  it('Should handle member_left_channel events as envisioned', function() {
    stubs.receiveMock.onReceived = function(msg) {
      assert.deepEqual(msg.constructor.name, "LeaveMessage");
      assert.deepEqual(msg.ts, stubs.event_timestamp);
      assert.deepEqual(msg.user.id, stubs.user.id);
      done();
    };
    slackbot.eventHandler({
      body: {
        event: {
          type: 'member_left_channel',
          user: stubs.user.id,
          channel: stubs.channel.id,
          ts: stubs.event_timestamp
        }
      },
      event: {
        type: 'member_left_channel',
        user: stubs.user.id,
        channel: stubs.channel.id,
        ts: stubs.event_timestamp
      }
    });
  });

  it('Should handle reaction_added events as envisioned', (t, done) => {
    const reactionMessage = {
      body: {
        event: {
          type: 'reaction_added',
          user: stubs.user.id,
          item_user: stubs.self,
          channel: stubs.channel.id,
          ts: stubs.event_timestamp,
          item: {
            type: 'message',
            channel: stubs.channel.id,
            ts: '1360782804.083113'
          },
          reaction: 'thumbsup',
          event_ts: '1360782804.083113'
    
        }
      },
      event: {
        type: 'reaction_added',
        user: stubs.user.id,
        item_user: stubs.self,
        channel: stubs.channel.id,
        ts: stubs.event_timestamp,
        item: {
          type: 'message',
          channel: stubs.channel.id,
          ts: '1360782804.083113'
        },
        reaction: 'thumbsup',
        event_ts: '1360782804.083113'
      }
    };

    stubs.receiveMock.onReceived = function(msg) {
      assert.deepEqual((msg instanceof ReactionMessage), true);
      assert.deepEqual(msg.user.id, stubs.user.id);
      assert.deepEqual(msg.user.room, stubs.channel.id);
      assert.deepEqual(msg.item_user.id, stubs.self.id);
      assert.deepEqual(msg.type, 'added');
      assert.deepEqual(msg.reaction, 'thumbsup');
      done();
    }
    slackbot.eventHandler(reactionMessage);
  });

  it('Should handle reaction_removed events as envisioned', (t, done) => {
    const reactionMessage = {
      body: {
        event: {
          type: 'reaction_removed',
          user: stubs.user.id,
          item_user: stubs.self,
          channel: stubs.channel.id,
          ts: stubs.event_timestamp,
          item: {
            type: 'message',
            channel: stubs.channel.id,
            ts: '1360782804.083113'
          },
          reaction: 'thumbsup',
          event_ts: '1360782804.083113'
    
        }
      },
      event: {
        type: 'reaction_removed',
        user: stubs.user.id,
        item_user: stubs.self,
        channel: stubs.channel.id,
        ts: stubs.event_timestamp,
        item: {
          type: 'message',
          channel: stubs.channel.id,
          ts: '1360782804.083113'
        },
        reaction: 'thumbsup',
        event_ts: '1360782804.083113'
      }
    };
    stubs.receiveMock.onReceived = function(msg) {
      assert.deepEqual((msg instanceof ReactionMessage), true);
      assert.deepEqual(msg.user.id, stubs.user.id);
      assert.deepEqual(msg.user.room, stubs.channel.id);
      assert.deepEqual(msg.item_user.id, stubs.self.id);
      assert.deepEqual(msg.type, 'removed');
      assert.deepEqual(msg.reaction, 'thumbsup');
      done();
    };
    slackbot.eventHandler(reactionMessage);
  });

  it('Should ignore messages it sent itself', (t, done) => {
    stubs.receiveMock.onReceived = function(msg) {
      assert.fail('Should not have received a message');
    };

    slackbot.eventHandler({
      body: {
        event: {
          type: 'message',
          text: 'Ignore me',
          user: stubs.self.id,
          channel: stubs.channel.id,
          ts: stubs.event_timestamp    
        }
      },
      event: {
        type: 'message',
        text: 'Ignore me',
        user: stubs.self.id,
        channel: stubs.channel.id,
        ts: stubs.event_timestamp    
      }
    });
    done();
  });

  it('Should handle empty users as envisioned', function(t, done){
    stubs.receiveMock.onReceived = function(msg) {
      assert.fail('Should not have received a message');
    };
    slackbot.eventHandler({
      body: {
        event: {
          type: 'message',
          text: 'Foo',
          user: '',
          channel: stubs.channel.id,
          ts: stubs.event_timestamp    
        }
      },
      event: {
        type: 'message',
        text: 'Foo',
        user: '',
        channel: stubs.channel.id,
        ts: stubs.event_timestamp    
      }
    });
    done();
  });

  it('Should handle file_shared events as envisioned', function() {
    const fileMessage = {
      body: {
        event: {
          type: 'file_shared',
          text: 'Foo',
          user: stubs.user.id,
          channel: stubs.channel.id,
          ts: stubs.event_timestamp,
          file_id: 'F2147483862',
          event_ts: stubs.event_timestamp
        }
      },
      event: {
        type: 'file_shared',
        text: 'Foo',
        user: stubs.user.id,
        channel: stubs.channel.id,
        ts: stubs.event_timestamp,
        file_id: 'F2147483862',
        event_ts: stubs.event_timestamp
      }
    };
    stubs.receiveMock.onReceived = function(msg) {
      assert.deepEqual((msg instanceof FileSharedMessage), true);
      assert.deepEqual(msg.user.id, stubs.user.id);
      assert.deepEqual(msg.user.room, stubs.channel.id);
      assert.deepEqual(msg.file_id, 'F2147483862');
    };
    slackbot.eventHandler(fileMessage);
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

  
