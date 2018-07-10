should = require 'should'
SlackMention = require('../src/mention')

describe 'buildText()', ->

  it 'Should decode entities', ->
    message = @slacktextmessage
    message.rawMessage.text = 'foo &gt; &amp; &lt; &gt;&amp;&lt;'
    message.buildText @client, () ->
      message.text.should.equal('foo > & < >&<')

  it 'Should remove formatting around <http> links', ->
    message = @slacktextmessage
    message.rawMessage.text = 'foo <http://www.example.com> bar'
    message.buildText @client, () ->
      message.text.should.equal 'foo http://www.example.com bar'

  it 'Should remove formatting around <https> links', ->
    message = @slacktextmessage
    message.rawMessage.text = 'foo <https://www.example.com> bar'
    message.buildText @client, () ->
      message.text.should.equal 'foo https://www.example.com bar'

  it 'Should remove formatting around <skype> links', ->
    message = @slacktextmessage
    message.rawMessage.text = 'foo <skype:echo123?call> bar'
    message.buildText @client, () ->
      message.text.should.equal 'foo skype:echo123?call bar'

  it 'Should remove formatting around <https> links with a label', ->
    message = @slacktextmessage
    message.rawMessage.text = 'foo <https://www.example.com|label> bar'
    message.buildText @client, () ->
      message.text.should.equal 'foo label (https://www.example.com) bar'

  it 'Should remove formatting around <https> links with a substring label', ->
    message = @slacktextmessage
    message.rawMessage.text = 'foo <https://www.example.com|example.com> bar'
    message.buildText @client, () ->
      message.text.should.equal 'foo https://www.example.com bar'

  it 'Should remove formatting around <https> links with a label containing entities', ->
    message = @slacktextmessage
    message.rawMessage.text = 'foo <https://www.example.com|label &gt; &amp; &lt;> bar'
    message.buildText @client, () ->
      message.text.should.equal 'foo label > & < (https://www.example.com) bar'

  it 'Should remove formatting around <mailto> links', ->
    message = @slacktextmessage
    message.rawMessage.text = 'foo <mailto:name@example.com> bar'
    message.buildText @client, () ->
      message.text.should.equal 'foo name@example.com bar'

  it 'Should remove formatting around <mailto> links with an email label', ->
    message = @slacktextmessage
    message.rawMessage.text = 'foo <mailto:name@example.com|name@example.com> bar'
    message.buildText @client, () ->
      message.text.should.equal 'foo name@example.com bar'

  it 'Should handle empty text with attachments', ->
    message = @slacktextmessage
    message.rawMessage.text = undefined
    message.rawMessage.attachments = [
      { fallback: 'first' },
    ]
    message.buildText @client, () ->
      message.text.should.equal '\nfirst'

  it 'Should handle an empty set of attachments', ->
    message = @slacktextmessage
    message.rawMessage.text = 'foo'
    message.rawMessage.attachments = []
    message.buildText @client, () ->
      message.text.should.equal 'foo'

  it 'Should change multiple links at once', ->
    message = @slacktextmessage
    message.rawMessage.text = 'foo <@U123|label> bar <#C123> <!channel> <https://www.example.com|label>'
    message.buildText @client, () ->
      message.text.should.equal 'foo @label bar #general @channel label (https://www.example.com)'

  it 'Should populate mentions with simple SlackMention object', ->
    message = @slacktextmessage
    message.rawMessage.text = 'foo <@U123> bar'
    message.buildText @client, () ->
      message.mentions.length.should.equal 1
      message.mentions[0].type.should.equal 'user'
      message.mentions[0].id.should.equal 'U123'
      should.equal (message.mentions[0] instanceof SlackMention), true

  it 'Should populate mentions with simple SlackMention object with label', ->
    message = @slacktextmessage
    message.rawMessage.text = 'foo <@U123|label> bar'
    message.buildText @client, () ->
      message.mentions.length.should.equal 1
      message.mentions[0].type.should.equal 'user'
      message.mentions[0].id.should.equal 'U123'
      should.equal message.mentions[0].info, undefined
      should.equal (message.mentions[0] instanceof SlackMention), true

  it 'Should populate mentions with multiple SlackMention objects', ->
    message = @slacktextmessage
    message.rawMessage.text = 'foo <@U123> bar <#C123> baz <@U123|label> qux'
    message.buildText @client, () ->
      message.mentions.length.should.equal 3
      should.equal (message.mentions[0] instanceof SlackMention), true
      should.equal (message.mentions[1] instanceof SlackMention), true
      should.equal (message.mentions[2] instanceof SlackMention), true

  it 'Should populate mentions with simple SlackMention object if user in brain', ->
    @client.updateUserInBrain(@stubs.user)
    message = @slacktextmessage
    message.rawMessage.text = 'foo <@U123> bar'
    message.buildText @client, () ->
      message.mentions.length.should.equal 1
      message.mentions[0].type.should.equal 'user'
      message.mentions[0].id.should.equal 'U123'
      should.equal (message.mentions[0] instanceof SlackMention), true

  it 'Should add conversation to cache', ->
    message = @slacktextmessage
    client = @client
    message.rawMessage.text = 'foo bar'
    message.buildText @client, () ->
      message.text.should.equal('foo bar')
      client.channelData.should.have.key('C123')

  it 'Should not modify conversation if it is not expired', ->
    message = @slacktextmessage
    client = @client
    client.channelData[@stubs.channel.id] = {
      channel: {id: @stubs.channel.id, name: 'baz'},
      updated: Date.now()
    }
    message.rawMessage.text = 'foo bar'
    message.buildText @client, () ->
      message.text.should.equal('foo bar')
      client.channelData.should.have.key('C123')
      client.channelData['C123'].channel.name.should.equal 'baz'

  it 'Should handle conversation errors', ->
    message = @slacktextmessage_invalid_conversation
    client = @client
    message.rawMessage.text = 'foo bar'
    message.buildText @client, () ->
      client.robot.logger.logs?.error.length.should.equal 1

  it 'Should flatten attachments', ->
    message = @slacktextmessage
    client = @client
    message.rawMessage.text = 'foo bar'
    message.rawMessage.attachments = [
      { fallback: 'first' },
      { fallback: 'second' }
    ]
    message.buildText @client, () ->
      message.text.should.equal 'foo bar\nfirst\nsecond'


describe 'replaceLinks()', ->

  it 'Should change <@U123> links to @name', ->
    @slacktextmessage.replaceLinks @client, 'foo <@U123> bar'
    .then((text) -> text.should.equal 'foo @name bar')

  it 'Should change <@U123|label> links to @label', ->
    @slacktextmessage.replaceLinks @client, 'foo <@U123|label> bar'
    .then((text) -> text.should.equal 'foo @label bar')

  it 'Should handle invalid User ID gracefully', ->
    @slacktextmessage.replaceLinks @client, 'foo <@U555> bar'
    .then((text) -> text.should.equal 'foo <@U555> bar')

  it 'Should handle empty User API response', ->
    @slacktextmessage.replaceLinks @client, 'foo <@U789> bar'
    .then((text) -> text.should.equal 'foo <@U789> bar')

  it 'Should change <#C123> links to #general', ->
    @slacktextmessage.replaceLinks @client, 'foo <#C123> bar'
    .then((text) -> text.should.equal 'foo #general bar')

  it 'Should change <#C123|label> links to #label', ->
    @slacktextmessage.replaceLinks @client, 'foo <#C123|label> bar'
    .then((text) -> text.should.equal 'foo #label bar')

  it 'Should handle invalid Conversation ID gracefully', ->
    @slacktextmessage.replaceLinks @client, 'foo <#C555> bar'
    .then((text) -> text.should.equal 'foo <#C555> bar')

  it 'Should handle empty Conversation API response', ->
    @slacktextmessage.replaceLinks @client, 'foo <#C789> bar'
    .then((text) -> text.should.equal 'foo <#C789> bar')

  it 'Should change <!everyone> links to @everyone', ->
    @slacktextmessage.replaceLinks @client, 'foo <!everyone> bar'
    .then((text) -> text.should.equal 'foo @everyone bar')

  it 'Should change <!channel> links to @channel', ->
    @slacktextmessage.replaceLinks @client, 'foo <!channel> bar'
    .then((text) -> text.should.equal 'foo @channel bar')

  it 'Should change <!group> links to @group', ->
    @slacktextmessage.replaceLinks @client, 'foo <!group> bar'
    .then((text) -> text.should.equal 'foo @group bar')

  it 'Should change <!here> links to @here', ->
    @slacktextmessage.replaceLinks @client, 'foo <!here> bar'
    .then((text) -> text.should.equal 'foo @here bar')

  it 'Should change <!subteam^S123|@subteam> links to @subteam', ->
    @slacktextmessage.replaceLinks @client, 'foo <!subteam^S123|@subteam> bar'
    .then((text) -> text.should.equal 'foo @subteam bar')

  it 'Should change <!foobar|hello> links to hello', ->
    @slacktextmessage.replaceLinks @client, 'foo <!foobar|hello> bar'
    .then((text) -> text.should.equal 'foo hello bar')

  it 'Should leave <!foobar> links as-is when no label is provided', ->
    @slacktextmessage.replaceLinks @client, 'foo <!foobar> bar'
    .then((text) -> text.should.equal 'foo <!foobar> bar')
