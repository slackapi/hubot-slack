{SlackBot} = require '../index'

should = require 'should'

describe 'Adapter', ->
  it 'Should initialize with a robot', ->
    @slackbot.robot.should.eql @stubs.robot

describe 'Login', ->
  it 'Should set the robot name', ->
    team =
      name: 'Test Team'
    user =
      name: 'bot'
    @slackbot.loggedIn(user, team)
    @slackbot.robot.name.should.equal 'bot'

describe 'Removing message formatting', ->
  it 'Should do nothing if there are no user links', ->
    foo = @slackbot.removeFormatting 'foo'
    foo.should.equal 'foo'

  it 'Should decode entities', ->
    foo = @slackbot.removeFormatting 'foo &gt; &amp; &lt; &gt;&amp;&lt;'
    foo.should.equal 'foo > & < >&<'

  it 'Should change <@U123> links to @name', ->
    foo = @slackbot.removeFormatting 'foo <@U123> bar'
    foo.should.equal 'foo @name bar'

  it 'Should change <@U123|label> links to label', ->
    foo = @slackbot.removeFormatting 'foo <@U123|label> bar'
    foo.should.equal 'foo label bar'

  it 'Should change <#C123> links to #general', ->
    foo = @slackbot.removeFormatting 'foo <#C123> bar'
    foo.should.equal 'foo #general bar'

  it 'Should change <#C123|label> links to label', ->
    foo = @slackbot.removeFormatting 'foo <#C123|label> bar'
    foo.should.equal 'foo label bar'

  it 'Should change <!everyone> links to @everyone', ->
    foo = @slackbot.removeFormatting 'foo <!everyone> bar'
    foo.should.equal 'foo @everyone bar'

  it 'Should change <!channel> links to @channel', ->
    foo = @slackbot.removeFormatting 'foo <!channel> bar'
    foo.should.equal 'foo @channel bar'

  it 'Should change <!group> links to @group', ->
    foo = @slackbot.removeFormatting 'foo <!group> bar'
    foo.should.equal 'foo @group bar'

  it 'Should change <!here> links to @here', ->
    foo = @slackbot.removeFormatting 'foo <!here> bar'
    foo.should.equal 'foo @here bar'

  it 'Should remove formatting around <http> links', ->
    foo = @slackbot.removeFormatting 'foo <http://www.example.com> bar'
    foo.should.equal 'foo http://www.example.com bar'

  it 'Should remove formatting around <https> links', ->
    foo = @slackbot.removeFormatting 'foo <https://www.example.com> bar'
    foo.should.equal 'foo https://www.example.com bar'

  it 'Should remove formatting around <skype> links', ->
    foo = @slackbot.removeFormatting 'foo <skype:echo123?call> bar'
    foo.should.equal 'foo skype:echo123?call bar'

  it 'Should remove formatting around <https> links with a label', ->
    foo = @slackbot.removeFormatting 'foo <https://www.example.com|label> bar'
    foo.should.equal 'foo label (https://www.example.com) bar'

  it 'Should remove formatting around <https> links with a substring label', ->
    foo = @slackbot.removeFormatting 'foo <https://www.example.com|example.com> bar'
    foo.should.equal 'foo https://www.example.com bar'

  it 'Should remove formatting around <https> links with a label containing entities', ->
    foo = @slackbot.removeFormatting 'foo <https://www.example.com|label &gt; &amp; &lt;> bar'
    foo.should.equal 'foo label > & < (https://www.example.com) bar'

  it 'Should remove formatting around <mailto> links', ->
    foo = @slackbot.removeFormatting 'foo <mailto:name@example.com> bar'
    foo.should.equal 'foo name@example.com bar'

  it 'Should remove formatting around <mailto> links with an email label', ->
    foo = @slackbot.removeFormatting 'foo <mailto:name@example.com|name@example.com> bar'
    foo.should.equal 'foo name@example.com bar'

  it 'Should change multiple links at once', ->
    foo = @slackbot.removeFormatting 'foo <@U123|label> bar <#C123> <!channel> <https://www.example.com|label>'
    foo.should.equal 'foo label bar #general @channel label (https://www.example.com)'

describe 'Send Messages', ->
  it 'Should send multiple messages', ->
    sentMessages = @slackbot.send {room: 'general'}, 'one', 'two', 'three'
    sentMessages.length.should.equal 3

  it 'Should not send empty messages', ->
    sentMessages = @slackbot.send {room: 'general'}, 'Hello', '', '', 'world!'
    sentMessages.length.should.equal 2

  it 'Should split long messages', ->
    lines = 'Hello, Slackbot\nHow are you?\n'
    # Make a very long message
    msg = lines
    len = 10000
    msg += lines while msg.length < len

    sentMessages = @slackbot.send {room: 'general'}, msg
    sentMessage = sentMessages.pop()
    sentMessage.length.should.equal Math.ceil(len / SlackBot.MAX_MESSAGE_LENGTH)

  it 'Should try to split on word breaks', ->
    msg = 'Foo bar baz'
    @slackbot.constructor.MAX_MESSAGE_LENGTH = 10
    sentMessages = @slackbot.send {room: 'general'}, msg
    sentMessage = sentMessages.pop()
    sentMessage.length.should.equal 2

  it 'Should split into max length chunks if there are no breaks', ->
    msg = 'Foobar'
    @slackbot.constructor.MAX_MESSAGE_LENGTH = 3
    sentMessages = @slackbot.send {room: 'general'}, msg
    sentMessage = sentMessages.pop()
    sentMessage.should.eql ['Foo', 'bar']

  it 'Should open a DM channel if needed', ->
    msg = 'Test'
    @slackbot.send {room: 'name'}, msg
    @stubs._msg.should.eql 'Test'

  it 'Should use an existing DM channel if possible', ->
    msg = 'Test'
    @slackbot.send {room: 'user2'}, msg
    @stubs._dmmsg.should.eql 'Test'

  it 'Should replace @name with <@U123> for mention', ->
    msg = 'foo @name: bar'
    sentMessages = @slackbot.send {room: 'general'}, msg
    sentMessage = sentMessages.pop()
    sentMessage.should.equal 'foo <@U123>: bar'

  it 'Should replace @name with <@U123> for mention (first word)', ->
    msg = '@name: bar'
    sentMessages = @slackbot.send {room: 'general'}, msg
    sentMessage = sentMessages.pop()
    sentMessage.should.equal '<@U123>: bar'

  it 'Should replace @name with <@U123> for mention (without colons)', ->
    msg = 'foo @name bar'
    sentMessages = @slackbot.send {room: 'general'}, msg
    sentMessage = sentMessages.pop()
    sentMessage.should.equal 'foo <@U123> bar'

  it 'Should replace @channel with <!channel> for mention', ->
    msg = 'foo @channel: bar'
    sentMessages = @slackbot.send {room: 'general'}, msg
    sentMessage = sentMessages.pop()
    sentMessage.should.equal 'foo <!channel>: bar'

  it 'Should replace multiple mentions with <!XXXX>', ->
    msg = 'foo @everyone: @channel: bar'
    sentMessages = @slackbot.send {room: 'general'}, msg
    sentMessage = sentMessages.pop()
    sentMessage.should.equal 'foo <!everyone>: <!channel>: bar'

  it 'Should replace multiple mentions with <!XXXX>/<@UXXXX>', ->
    msg = 'foo @everyone: @name: bar'
    sentMessages = @slackbot.send {room: 'general'}, msg
    sentMessage = sentMessages.pop()
    sentMessage.should.equal 'foo <!everyone>: <@U123>: bar'

  it 'Should not replace @name with <@U123> for mention when there is a typo', ->
    msg = 'foo @naame: bar'
    sentMessages = @slackbot.send {room: 'general'}, msg
    sentMessage = sentMessages.pop()
    sentMessage.should.equal 'foo @naame: bar'
