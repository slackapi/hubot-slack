should = require 'should'
chai = require 'chai'
{ EnterMessage, LeaveMessage, TopicMessage, CatchAllMessage, Robot } = require.main.require 'hubot'
{ SlackTextMessage, ReactionMessage } = require '../src/message'
SlackClient = require '../src/client'

describe 'buildText()', ->

  it 'Should decode entities', ->
    message = @slacktextmessage
    message.rawMessage.text = 'foo &gt; &amp; &lt; &gt;&amp;&lt;'
    message.buildText () ->
      message.text.should.equal('foo > & < >&<')

  it 'Should change <@U123> links to @name', ->
    @slacktextmessage.replaceLinks 'foo <@U123> bar'
    .then((text) -> text.should.equal 'foo @name bar')

  it 'Should change <@U123|label> links to @label', ->
    @slacktextmessage.replaceLinks 'foo <@U123|label> bar'
    .then((text) -> text.should.equal 'foo @label bar')

  it 'Should change <#C123> links to #general', ->
    @slacktextmessage.replaceLinks 'foo <#C123> bar'
    .then((text) -> text.should.equal 'foo #general bar')

  it 'Should change <#C123|label> links to #label', ->
    @slacktextmessage.replaceLinks 'foo <#C123|label> bar'
    .then((text) -> text.should.equal 'foo #label bar')

  it 'Should change <!everyone> links to @everyone', ->
    @slacktextmessage.replaceLinks 'foo <!everyone> bar'
    .then((text) -> text.should.equal 'foo @everyone bar')

  it 'Should change <!channel> links to @channel', ->
    @slacktextmessage.replaceLinks 'foo <!channel> bar'
    .then((text) -> text.should.equal 'foo @channel bar')

  it 'Should change <!group> links to @group', ->
    @slacktextmessage.replaceLinks 'foo <!group> bar'
    .then((text) -> text.should.equal 'foo @group bar')

  it 'Should change <!here> links to @here', ->
    @slacktextmessage.replaceLinks 'foo <!here> bar'
    .then((text) -> text.should.equal 'foo @here bar')

  it 'Should change <!subteam^S123|@subteam> links to @subteam', ->
    @slacktextmessage.replaceLinks 'foo <!subteam^S123|@subteam> bar'
    .then((text) -> text.should.equal 'foo @subteam bar')

  it 'Should change <!foobar|hello> links to hello', ->
    @slacktextmessage.replaceLinks 'foo <!foobar|hello> bar'
    .then((text) -> text.should.equal 'foo hello bar')

  it 'Should leave <!foobar> links as-is when no label is provided', ->
    @slacktextmessage.replaceLinks 'foo <!foobar> bar'
    .then((text) -> text.should.equal 'foo <!foobar> bar')

  it 'Should remove formatting around <http> links', ->
    message = @slacktextmessage
    message.rawMessage.text = 'foo <http://www.example.com> bar'
    message.buildText () ->
      message.text.should.equal 'foo http://www.example.com bar'

  it 'Should remove formatting around <https> links', ->
    message = @slacktextmessage
    message.rawMessage.text = 'foo <https://www.example.com> bar'
    message.buildText () ->
      message.text.should.equal 'foo https://www.example.com bar'

  it 'Should remove formatting around <skype> links', ->
    message = @slacktextmessage
    message.rawMessage.text = 'foo <skype:echo123?call> bar'
    message.buildText () ->
      message.text.should.equal 'foo skype:echo123?call bar'

  it 'Should remove formatting around <https> links with a label', ->
    message = @slacktextmessage
    message.rawMessage.text = 'foo <https://www.example.com|label> bar'
    message.buildText () ->
      message.text.should.equal 'foo label (https://www.example.com) bar'

  it 'Should remove formatting around <https> links with a substring label', ->
    message = @slacktextmessage
    message.rawMessage.text = 'foo <https://www.example.com|example.com> bar'
    message.buildText () ->
      message.text.should.equal 'foo https://www.example.com bar'

  it 'Should remove formatting around <https> links with a label containing entities', ->
    message = @slacktextmessage
    message.rawMessage.text = 'foo <https://www.example.com|label &gt; &amp; &lt;> bar'
    message.buildText () ->
      message.text.should.equal 'foo label > & < (https://www.example.com) bar'

  it 'Should remove formatting around <mailto> links', ->
    message = @slacktextmessage
    message.rawMessage.text = 'foo <mailto:name@example.com> bar'
    message.buildText () ->
      message.text.should.equal 'foo name@example.com bar'

  it 'Should remove formatting around <mailto> links with an email label', ->
    message = @slacktextmessage
    message.rawMessage.text = 'foo <mailto:name@example.com|name@example.com> bar'
    message.buildText () ->
      message.text.should.equal 'foo name@example.com bar'

  it 'Should change multiple links at once', ->
    message = @slacktextmessage
    message.rawMessage.text = 'foo <@U123|label> bar <#C123> <!channel> <https://www.example.com|label>'
    message.buildText () ->
      message.text.should.equal 'foo @label bar #general @channel label (https://www.example.com)'