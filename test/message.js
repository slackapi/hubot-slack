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
const axiosMock = {
  default: {
    create() {
      
    }
  },
  headers: {
    post: {}
  }
};
hookModuleToReturnMockFromRequire('hubot-slack', hubotSlackMock);
hookModuleToReturnMockFromRequire('axios', axiosMock);

const SlackMention = require('../src/mention');


describe('buildText()', function() {
  let stubs, client, slacktextmessage, slacktextmessage_invalid_conversation;
  beforeEach(function() {
    ({ stubs, client, slacktextmessage, slacktextmessage_invalid_conversation } = require('./stubs.js')());
  });
  
  it('Should decode entities', function(t, done) {
    const message = slacktextmessage;
    message.rawMessage.text = 'foo &gt; &amp; &lt; &gt;&amp;&lt;';
    message.buildText(client, () => {
      assert.deepEqual(message.text, 'foo > & < >&<');
      done();
    });
  });

  it('Should remove formatting around <http> links', function(t, done) {
    const message = slacktextmessage;
    message.rawMessage.text = 'foo <http://www.example.com> bar';
    message.buildText(client, () => {
      assert.deepEqual(message.text, 'foo http://www.example.com bar');
      done();
    });
  });

  it('Should remove formatting around <https> links', function(t, done) {
    const message = slacktextmessage;
    message.rawMessage.text = 'foo <https://www.example.com> bar';
    message.buildText(client, () => {
      assert.deepEqual(message.text, 'foo https://www.example.com bar');
      done();
    });
  });

  it('Should remove formatting around <skype> links', function(t, done) {
    const message = slacktextmessage;
    message.rawMessage.text = 'foo <skype:echo123?call> bar';
    message.buildText(client, () => {
      assert.deepEqual(message.text, 'foo skype:echo123?call bar');
      done();
    });
  });

  it('Should remove formatting around <https> links with a label', function(t, done) {
    const message = slacktextmessage;
    message.rawMessage.text = 'foo <https://www.example.com|label> bar';
    message.buildText(client, () => {
      assert.deepEqual(message.text, 'foo label (https://www.example.com) bar');
      done();
    });
  });

  it('Should remove formatting around <https> links with a substring label', function(t, done) {
    const message = slacktextmessage;
    message.rawMessage.text = 'foo <https://www.example.com|example.com> bar';
    message.buildText(client, () => { 
      assert.deepEqual(message.text, 'foo https://www.example.com bar');
      done();
    });
  });

  it('Should remove formatting around <https> links with a label containing entities', function(t, done) {
    const message = slacktextmessage;
    message.rawMessage.text = 'foo <https://www.example.com|label &gt; &amp; &lt;> bar';
    message.buildText(client, () => {
      assert.deepEqual(message.text, 'foo label > & < (https://www.example.com) bar');
      done();
    });
  });

  it('Should remove formatting around <mailto> links', function(t, done) {
    const message = slacktextmessage;
    message.rawMessage.text = 'foo <mailto:name@example.com> bar';
    message.buildText(client, () => { 
      assert.deepEqual(message.text, 'foo name@example.com bar');
      done();
    });
  });

  it('Should remove formatting around <mailto> links with an email label', function(t, done) {
    const message = slacktextmessage;
    message.rawMessage.text = 'foo <mailto:name@example.com|name@example.com> bar';
    message.buildText(client, () => {
      assert.deepEqual(message.text, 'foo name@example.com bar');
      done();
    });
  });

  it('Should handle empty text with attachments', function(t, done) {
    const message = slacktextmessage;
    message.rawMessage.text = undefined;
    message.rawMessage.attachments = [
      { fallback: 'first' },
    ];
    message.buildText(client, () => {
      assert.deepEqual(message.text, '\nfirst');
      done();
    });
  });

  it('Should handle an empty set of attachments', function(t, done) {
    const message = slacktextmessage;
    message.rawMessage.text = 'foo';
    message.rawMessage.attachments = [];
    message.buildText(client, () => {
      assert.deepEqual(message.text, 'foo');
      done();
    });
  });

  it('Should change multiple links at once', function(t, done) {
    const message = slacktextmessage;
    message.rawMessage.text = 'foo <@U123|label> bar <#C123> <!channel> <https://www.example.com|label>';
    message.buildText(client, () => {
      assert.deepEqual(message.text, 'foo @label bar #general @channel label (https://www.example.com)');
      done();
    });
  });

  it('Should populate mentions with simple SlackMention object', function(t, done) {
    const message = slacktextmessage;
    message.rawMessage.text = 'foo <@U123> bar';
    message.buildText(client, function() {
      assert.deepEqual(message.mentions.length, 1);
      assert.deepEqual(message.mentions[0].type, 'user');
      assert.deepEqual(message.mentions[0].id, 'U123');
      assert.deepEqual((message.mentions[0] instanceof SlackMention), true);
      done();
    });
  });

  it('Should populate mentions with simple SlackMention object with label', function(t, done) {
    const message = slacktextmessage;
    message.rawMessage.text = 'foo <@U123|label> bar';
    message.buildText(client, function() {
      assert.deepEqual(message.mentions.length, 1);
      assert.deepEqual(message.mentions[0].type, 'user');
      assert.deepEqual(message.mentions[0].id, 'U123');
      assert.deepEqual(message.mentions[0].info, undefined);
      assert.deepEqual((message.mentions[0] instanceof SlackMention), true);
      done();
    });
  });

  it('Should populate mentions with multiple SlackMention objects', function(t, done) {
    const message = slacktextmessage;
    message.rawMessage.text = 'foo <@U123> bar <#C123> baz <@U123|label> qux';
    message.buildText(client, function() {
      assert.deepEqual(message.mentions.length, 3);
      assert.deepEqual((message.mentions[0] instanceof SlackMention), true);
      assert.deepEqual((message.mentions[1] instanceof SlackMention), true);
      assert.deepEqual((message.mentions[2] instanceof SlackMention), true);
      done();
    });
  });

  it('Should populate mentions with simple SlackMention object if user in brain', function(t, done) {
    client.updateUserInBrain(stubs.user);
    const message = slacktextmessage;
    message.rawMessage.text = 'foo <@U123> bar';
    message.buildText(client, function() {
      assert.deepEqual(message.mentions.length, 1);
      assert.deepEqual(message.mentions[0].type, 'user');
      assert.deepEqual(message.mentions[0].id, 'U123');
      assert.deepEqual((message.mentions[0] instanceof SlackMention), true);
      done();
    });
  });

  it('Should add conversation to cache', function(t, done) {
    const message = slacktextmessage;
    message.rawMessage.text = 'foo bar';
    message.buildText(client, function() {
      assert.deepEqual(message.text, 'foo bar');
      assert.ok(Object.keys(client.channelData).includes('C123'));
      done();
    });
  });

  it('Should not modify conversation if it is not expired', function(t, done) {
    const message = slacktextmessage;
    client.channelData[stubs.channel.id] = {
      channel: {id: stubs.channel.id, name: 'baz'},
      updated: Date.now()
    };
    message.rawMessage.text = 'foo bar';
    message.buildText(client, function() {
      assert.deepEqual(message.text, 'foo bar');
      assert.ok(Object.keys(client.channelData).includes('C123'));
      assert.deepEqual(client.channelData['C123'].channel.name, 'baz');
      done();
    });
  });

  it('Should handle conversation errors', function(t, done) {
    const message = slacktextmessage_invalid_conversation;
    message.rawMessage.text = 'foo bar';
    message.buildText(client, () => {
      client.robot.logger.logs != null ? assert.deepEqual(client.robot.logger.logs.error.length, 1) : undefined;
      done();
    });
  });

  it('Should flatten attachments', function(t, done) {
    const message = slacktextmessage;
    message.rawMessage.text = 'foo bar';
    message.rawMessage.attachments = [
      { fallback: 'first' },
      { fallback: 'second' }
    ];
    message.buildText(client, () => {
      assert.deepEqual(message.text, 'foo bar\nfirst\nsecond');
      done();
    });
  });
});


describe('replaceLinks()', function() {
  let stubs, client, slacktextmessage, slacktextmessage_invalid_conversation;
  beforeEach(function() {
    ({ stubs, client, slacktextmessage, slacktextmessage_invalid_conversation } = require('./stubs.js')());
  });
  
  it('Should change <@U123> links to @name', async function() {
    const text = await slacktextmessage.replaceLinks(client, 'foo <@U123> bar');
    assert.deepEqual(text, 'foo @name bar');
  });

  it('Should change <@U123|label> links to @label', async function() {
    const text = await slacktextmessage.replaceLinks(client, 'foo <@U123|label> bar');
    assert.deepEqual(text, 'foo @label bar');
  });

  it('Should handle invalid User ID gracefully', async function() {
    const text = await slacktextmessage.replaceLinks(client, 'foo <@U555> bar');
    assert.deepEqual(text, 'foo <@U555> bar');
  });

  it('Should handle empty User API response', async function() {
    const text = await slacktextmessage.replaceLinks(client, 'foo <@U789> bar');
    assert.deepEqual(text, 'foo <@U789> bar');
  });

  it('Should change <#C123> links to #general', async function() {
    const text = await slacktextmessage.replaceLinks(client, 'foo <#C123> bar');
    assert.deepEqual(text, 'foo #general bar');
  });

  it('Should change <#C123|label> links to #label', async function() {
    const text = await slacktextmessage.replaceLinks(client, 'foo <#C123|label> bar');
    assert.deepEqual(text, 'foo #label bar');
  });

  it('Should handle invalid Conversation ID gracefully', async function() {
    const text = await slacktextmessage.replaceLinks(client, 'foo <#C555> bar');
    assert.deepEqual(text, 'foo <#C555> bar');
  });

  it('Should handle empty Conversation API response', async function() {
    const text = await slacktextmessage.replaceLinks(client, 'foo <#C789> bar');
    assert.deepEqual(text, 'foo <#C789> bar');
  });

  it('Should change <!everyone> links to @everyone', async function() {
    const text = await slacktextmessage.replaceLinks(client, 'foo <!everyone> bar');
    assert.deepEqual(text, 'foo @everyone bar');
  });

  it('Should change <!channel> links to @channel', async function() {
    const text = await slacktextmessage.replaceLinks(client, 'foo <!channel> bar');
    assert.deepEqual(text, 'foo @channel bar');
  });

  it('Should change <!group> links to @group', async function() {
    const text = await slacktextmessage.replaceLinks(client, 'foo <!group> bar');
    assert.deepEqual(text, 'foo @group bar');
  });

  it('Should change <!here> links to @here', async function() {
    const text = await slacktextmessage.replaceLinks(client, 'foo <!here> bar');
    assert.deepEqual(text, 'foo @here bar');
  });

  it('Should change <!subteam^S123|@subteam> links to @subteam', async function() {
    const text = await slacktextmessage.replaceLinks(client, 'foo <!subteam^S123|@subteam> bar');
    assert.deepEqual(text, 'foo @subteam bar');
  });

  it('Should change <!foobar|hello> links to hello', async function() {
    const text = await slacktextmessage.replaceLinks(client, 'foo <!foobar|hello> bar');
    assert.deepEqual(text, 'foo hello bar');
  });

  it('Should leave <!foobar> links as-is when no label is provided', async function() {
    const text = await slacktextmessage.replaceLinks(client, 'foo <!foobar> bar');
    assert.deepEqual(text, 'foo <!foobar> bar');
  });
});
