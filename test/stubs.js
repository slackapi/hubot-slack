/*
 * decaffeinate suggestions:
 * DS101: Remove unnecessary use of Array.from
 * DS102: Remove unnecessary code created because of implicit returns
 * DS207: Consider shorter variations of null checks
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/main/docs/suggestions.md
 */
// Setup stubs used by the other tests

const SlackBot = require('../src/bot');
const SlackClient = require('../src/client');
const {EventEmitter} = require('events');
const { SlackTextMessage } = require('../src/message');
// Use Hubot's brain in our stubs
const {Brain, Robot} = require('hubot');

require('../src/extensions');

// Stub a few interfaces to grease the skids for tests. These are intentionally
// as minimal as possible and only provide enough to make the tests possible.
// Stubs are recreated before each test.
module.exports = function() {
  const stubs = {};

  stubs._sendCount = 0;
  stubs.send = (envelope, text, opts) => {
    stubs._room = envelope.room;
    stubs._opts = opts;
    if ((/^[UD@][\d\w]+/.test(stubs._room)) || (stubs._room === stubs.DM.id)) {
      stubs._dmmsg = text;
    } else {
      stubs._msg = text;
    }
    return stubs._sendCount = stubs._sendCount + 1;
  };

  // These objects are of conversation shape: https://api.slack.com/types/conversation
  stubs.channel = {
    id: 'C123',
    name: 'general'
  };
  stubs.DM = {
    id: 'D1232',
    is_im: true
  };
  stubs.group = {
    id: 'G12324',
    is_mpim: true
  };

  // These objects are conversation IDs used to siwtch behavior of another stub
  stubs.channelWillFailChatPost = "BAD_CHANNEL";

  // These objects are of user shape: https://api.slack.com/types/user
  stubs.user = {
    id: 'U123',
    name: 'name', // NOTE: this property is dynamic and should only be used for display purposes
    real_name: 'real_name',
    profile: {
      email: 'email@example.com'
    },
    misc: 'misc'
  };
  stubs.userperiod = {
    name: 'name.lname',
    id: 'U124',
    profile: {
      email: 'name.lname@example.com'
    }
  };
  stubs.userhyphen = {
    name: 'name-lname',
    id: 'U125',
    profile: {
      email: 'name-lname@example.com'
    }
  };
  stubs.usernoprofile = {
    name: 'name',
    real_name: 'real_name',
    id: 'U126',
    misc: 'misc'
  };
  stubs.usernoemail = {
    name: 'name',
    real_name: 'real_name',
    id: 'U126',
    profile: {
      foo: 'bar'
    },
    misc: 'misc'
  };
  stubs.userdeleted = {
    name: 'name',
    id: 'U127',
    deleted: true
  };

  stubs.bot = {
    name: 'testbot',
    user: 'testbot',
    id: 'B123',
    user_id: 'U123'
  };
  stubs.undefined_user_bot = {
    name: 'testbot',
    id: 'B789'
  };
  stubs.slack_bot = {
    name: 'slackbot',
    user: 'slackbot',
    id: 'B01',
    user_id: 'USLACKBOT'
  };
  stubs.self = {
    name: 'self',
    user: 'self',
    user_id: 'U456',
    bot_id: 'B456',
    profile: {
      email: 'self@example.com'
    }
  };
  stubs.self_bot = {
    name: 'self',
    user: 'self',
    user_id: 'B456',
    profile: {
      email: 'self@example.com'
    }
  };
  stubs.org_user_not_in_workspace = {
    name: 'name',
    id: 'W123',
    profile: {
      email: 'org_not_in_workspace@example.com'
    }
  };
  stubs.org_user_not_in_workspace_in_channel = {
    name: 'name',
    id: 'W123',
    profile: {
      email: 'org_not_in_workspace@example.com'
    }
  };
  stubs.team = {
    name: 'Example Team',
    id: 'T123'
  };
  stubs.expired_timestamp = 1528238205453;
  stubs.event_timestamp = '1360782804.083113';

  // Slack client
  stubs.client = {
    dataStore: {
      getUserById: id => {
        for (let user of stubs.client.dataStore.users) {
          if (user.id === id) { return user; }
        }
      },
      getBotById: id => {
        for (let bot of stubs.client.dataStore.bots) {
          if (bot.id === id) { return bot; }
        }
      },
      getUserByName: name => {
        for (let user of stubs.client.dataStore.users) {
          if (user.name === name) { return user; }
        }
      },
      getChannelById: id => {
        if (stubs.channel.id === id) { return stubs.channel; }
      },
      getChannelGroupOrDMById: id => {
        if (stubs.channel.id === id) { return stubs.channel; }
      },
      getChannelGroupOrDMByName: name => {
        if (stubs.channel.name === name) { return stubs.channel; }
        for (let dm of stubs.client.dataStore.dms) {
          if (dm.name === name) { return dm; }
        }
      },
      users: [stubs.user, stubs.self, stubs.userperiod, stubs.userhyphen],
      bots: [stubs.bot],
      dms: [{
        name: 'user2',
        id: 'D5432'
      }
      ]
    }
  };

  stubs.authMock = {
    test: () => {
      return Promise.resolve({
        user_id: stubs.self.id,
        user: stubs.self.name,
        team: stubs.team.name,
      });
    }
  };


  stubs.socket = {
    connected: false,
    async start() {
      this.connected = true;
    },
    disconnect() {
      this.connected = false;
    },
    sendMessage(msg, room) {
      return stubs.send(room, msg);
    },
    dataStore: {
      getUserById(id) {
        switch (id) {
          case stubs.user.user_id: return stubs.user;
          case stubs.bot.user_id: return stubs.bot;
          case stubs.self.user_id: return stubs.self;
          case stubs.self_bot.user_id: return stubs.self_bot;
          default: return undefined;
        }
      },
      getChannelGroupOrDMById(id) {
        switch (id) {
          case stubs.channel.id: return stubs.channel;
          case stubs.DM.id: return stubs.DM;
        }
      }
    }
  };

  stubs.chatMock = {
    postMessage({channel, text}, opts) {
      if (channel === stubs.channelWillFailChatPost) { return Promise.reject(new Error("stub error")); }
      stubs.send({room: channel, text}, text, opts);
      return Promise.resolve();
    }
  };
  stubs.conversationsMock = {
    setTopic: (id, topic) => {
      stubs._topic = topic;
      if (stubs.receiveMock.onTopic != null) { 
        stubs.receiveMock.onTopic(stubs._topic);
      }
      return Promise.resolve();
    },
    info: conversationId => {
      if (conversationId === stubs.channel.id) {
        return Promise.resolve({ok: true, channel: stubs.channel});
      } else if (conversationId === stubs.DM.id) {
        return Promise.resolve({ok: true, channel: stubs.DM});
      } else if (conversationId === 'C789') {
        return Promise.resolve();
      } else {
        return Promise.reject(new Error('conversationsMock could not match conversation ID'));
      }
    }
  };
  stubs.botsMock = {
    info: event => {
      const botId = event.bot;
      if (botId === stubs.bot.id) {
        return Promise.resolve({ok: true, bot: stubs.bot});
      } else if (botId === stubs.undefined_user_bot.id) {
        return Promise.resolve({ok: true, bot: stubs.undefined_user_bot});
      } else {
        return Promise.reject(new Error('botsMock could not match bot ID'));
      }
    }
  };
  stubs.usersMock = {
    list: (opts, cb) => {
      stubs._listCount = (stubs != null ? stubs._listCount : undefined) ? stubs._listCount + 1 : 1;
      if (stubs != null ? stubs._listError : undefined) { return cb(new Error('mock error')); }
      if ((opts != null ? opts.cursor : undefined) === 'mock_cursor') {
        return cb(null, stubs.userListPageLast);
      } else {
        return cb(null, stubs.userListPageWithNextCursor);
      }
    },
    info(params) {
      if (params.user === stubs.user.id) {
        return Promise.resolve({ok: true, user: stubs.user});
      } else if (params.user === stubs.org_user_not_in_workspace.id) {
        return Promise.resolve({ok: true, user: stubs.org_user_not_in_workspace});
      } else if (params.user === 'U789') {
        return Promise.resolve();
      } else {
        return Promise.reject(new Error('usersMock could not match user ID'));
      }
    }
  };
  stubs.userListPageWithNextCursor = {
    members: [{ id: 1 }, { id: 2 }, { id: 4, profile: { bot_id: 'B1' } }],
    response_metadata: {
      next_cursor: 'mock_cursor'
    }
  };
  stubs.userListPageLast = {
    members: [{ id: 3 }],
    response_metadata: {
      next_cursor: ''
    }
  };

  stubs.responseUsersList = {
    ok: true,
    members: [stubs.user, stubs.userperiod]
  };
  stubs.wrongResponseUsersList = {
    ok: false,
    members: []
  };
  // Hubot.Robot instance
  stubs.robot = new EventEmitter;
    // noop the logging
  stubs.robot.logger = {
    logs: {},
    log(type, message) {
      if (!this.logs[type]) { 
        this.logs[type] = [];
      }
      return this.logs[type].push(message);
    },
    info(message) {
      return this.log('info', message);
    },
    debug(message) {
      return this.log('debug', message);
    },
    error(message) {
      return this.log('error', message);
    },
    warning(message) {
      return this.log('warning', message);
    }
  };
  // attach a real Brain to the robot
  stubs.robot.brain = new Brain(stubs.robot);
  stubs.robot.name = 'self';
  stubs.robot.listeners = [];
  stubs.robot.listen = Robot.prototype.listen.bind(stubs.robot);
  stubs.robot.hearReaction = Robot.prototype.hearReaction.bind(stubs.robot);
  stubs.robot.fileShared = Robot.prototype.fileShared.bind(stubs.robot);
  stubs.callback = ((() => "done"))();

  stubs.receiveMock = {
    receive: (message, user) => {
      stubs._received = message;
      if (stubs.receiveMock.onReceived != null) { 
        return stubs.receiveMock.onReceived(message);
      }
    }
  };

  // Generate a new slack instance for each test.
  let slackbot = new SlackBot(stubs.robot, {botToken: 'xoxb-faketoken', appToken: 'xapp-faketoken'});

  Object.assign(slackbot.client, stubs.client);
  Object.assign(slackbot.client.socket, stubs.socket);
  Object.assign(slackbot.client.web.auth, stubs.authMock);
  Object.assign(slackbot.client.web.chat, stubs.chatMock);
  Object.assign(slackbot.client.web.users, stubs.usersMock);
  Object.assign(slackbot.client.web.conversations, stubs.conversationsMock);
  Object.assign(slackbot, stubs.receiveMock);
  slackbot.self = stubs.self;

  let slacktextmessage = new SlackTextMessage(stubs.self, undefined, undefined, {text: undefined}, stubs.channel.id, undefined, slackbot.client);

  let slacktextmessage_invalid_conversation = new SlackTextMessage(stubs.self, undefined, undefined, {text: undefined}, 'C888', undefined, slackbot.client);

  let client = new SlackClient({botToken: 'xoxb-faketoken', appToken: 'xapp-faketoken'}, stubs.robot);
  Object.assign(client.socket, stubs.socket);
  Object.assign(client.web.auth, stubs.authMock);
  Object.assign(client.web.chat, stubs.chatMock);
  Object.assign(client.web.conversations, stubs.conversationsMock);
  Object.assign(client.web.users, stubs.usersMock);
  Object.assign(client.web.bots, stubs.botsMock);
  return {
    client,
    slacktextmessage,
    slackbot,
    stubs,
    slacktextmessage_invalid_conversation
  };
};
