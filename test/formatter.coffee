should = require 'should'

describe 'incoming()', ->

  it 'Should do nothing if there are no user links', ->
    foo = @formatter.incoming {text: 'foo'}
    foo.should.equal 'foo'


    


describe 'links()', ->

  it 'Should decode entities', ->
    foo = @formatter.links 'foo &gt; &amp; &lt; &gt;&amp;&lt;'
    foo.should.equal 'foo > & < >&<'

  it 'Should change <@U123> links to @name', ->
    foo = @formatter.links 'foo <@U123> bar'
    foo.should.equal 'foo @name bar'

  it 'Should change <@U123|label> links to @label', ->
    foo = @formatter.links 'foo <@U123|label> bar'
    foo.should.equal 'foo @label bar'

  it 'Should change <#C123> links to #general', ->
    foo = @formatter.links 'foo <#C123> bar'
    foo.should.equal 'foo #general bar'

  it 'Should change <#C123|label> links to #label', ->
    foo = @formatter.links 'foo <#C123|label> bar'
    foo.should.equal 'foo #label bar'

  it 'Should change <!everyone> links to @everyone', ->
    foo = @formatter.links 'foo <!everyone> bar'
    foo.should.equal 'foo @everyone bar'

  it 'Should change <!channel> links to @channel', ->
    foo = @formatter.links 'foo <!channel> bar'
    foo.should.equal 'foo @channel bar'

  it 'Should change <!group> links to @group', ->
    foo = @formatter.links 'foo <!group> bar'
    foo.should.equal 'foo @group bar'

  it 'Should change <!here> links to @here', ->
    foo = @formatter.links 'foo <!here> bar'
    foo.should.equal 'foo @here bar'

  it 'Should change <!subteam^S123|@subteam> links to @subteam', ->
    foo = @formatter.links 'foo <!subteam^S123|@subteam> bar'
    foo.should.equal 'foo @subteam bar'

  it 'Should change <!foobar|hello> links to hello', ->
    foo = @formatter.links 'foo <!foobar|hello> bar'
    foo.should.equal 'foo hello bar'

  it 'Should leave <!foobar> links as-is when no label is provided', ->
    foo = @formatter.links 'foo <!foobar> bar'
    foo.should.equal 'foo <!foobar> bar'

  it 'Should remove formatting around <http> links', ->
    foo = @formatter.links 'foo <http://www.example.com> bar'
    foo.should.equal 'foo http://www.example.com bar'

  it 'Should remove formatting around <https> links', ->
    foo = @formatter.links 'foo <https://www.example.com> bar'
    foo.should.equal 'foo https://www.example.com bar'

  it 'Should remove formatting around <skype> links', ->
    foo = @formatter.links 'foo <skype:echo123?call> bar'
    foo.should.equal 'foo skype:echo123?call bar'

  it 'Should remove formatting around <https> links with a label', ->
    foo = @formatter.links 'foo <https://www.example.com|label> bar'
    foo.should.equal 'foo label (https://www.example.com) bar'

  it 'Should remove formatting around <https> links with a substring label', ->
    foo = @formatter.links 'foo <https://www.example.com|example.com> bar'
    foo.should.equal 'foo https://www.example.com bar'

  it 'Should remove formatting around <https> links with a label containing entities', ->
    foo = @formatter.links 'foo <https://www.example.com|label &gt; &amp; &lt;> bar'
    foo.should.equal 'foo label > & < (https://www.example.com) bar'

  it 'Should remove formatting around <mailto> links', ->
    foo = @formatter.links 'foo <mailto:name@example.com> bar'
    foo.should.equal 'foo name@example.com bar'

  it 'Should remove formatting around <mailto> links with an email label', ->
    foo = @formatter.links 'foo <mailto:name@example.com|name@example.com> bar'
    foo.should.equal 'foo name@example.com bar'

  it 'Should change multiple links at once', ->
    foo = @formatter.links 'foo <@U123|label> bar <#C123> <!channel> <https://www.example.com|label>'
    foo.should.equal 'foo @label bar #general @channel label (https://www.example.com)'



describe 'flatten()', ->

  it 'Should return a basic message passed untouched', ->
    foo = @formatter.flatten {text: 'foo'}
    foo.should.equal 'foo'

  it 'Should concatenate attachments', ->
    foo = @formatter.flatten {text: 'foo', attachments: [{fallback: 'bar'}, {fallback: 'baz'}, {fallback: 'qux'}]}
    foo.should.equal 'foo\nbar\nbaz\nqux'
