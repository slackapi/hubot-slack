# Setup stubs used by the other tests

{SlackBot} = require '../index'

# Stub a few interfaces to grease the skids for tests. These are intentionally
# as minimal as possible and only provide enough to make the tests possible.
# Stubs are recreated before each test.
beforeEach ->
  @stubs =
    # Slack client
    channel:
      name: 'general'
      send: (msg) -> msg
    client:
      getUserByID: (id) ->
        {name: 'name', email_address: 'email@example.com'}
      getChannelByID: (id) =>
        @stubs.channel
      getChannelGroupOrDMByName: () =>
        @stubs.channel
    # Hubot.Robot instance
    robot:
      # noop the logging
      logger:
        info: ->
        debug: ->

# Generate a new slack instance for each test.
beforeEach ->
  @slackbot = new SlackBot @stubs.robot
  @slackbot.client = @stubs.client
