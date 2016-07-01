Formatter = require '../src/Formatter'

should = require 'should'

describe 'Handling message formatting', ->
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