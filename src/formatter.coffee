MESSAGE_RESERVED_KEYWORDS = ['channel','group','everyone','here']


class SlackFormatter

  ###*
  # SlackFormatter transforms raw message text into a flat string representation by removing special formatting.
  # For example, a user mention would be encoded as "<@U123456|username>" in the input text, and corresponding output
  # would read "@username". See: <https://api.slack.com/docs/formatting>
  #
  # @deprecated This class is no longer used for internal operations since 4.5.0. It will be removed in 5.0.0.
  #
  # @param {SlackDataStore} dataStore - an RTM client DataStore instance
  # @param {Robot} robot - a Hubot robot instance
  ###
  constructor: (@dataStore, @robot) ->

  ###*
  # Formats links and ids
  ###
  links: (text) ->
    @warnForDeprecation
    regex = ///
      <              # opening angle bracket
      ([@#!])?       # link type
      ([^>|]+)       # link
      (?:\|          # start of |label (optional)
      ([^>]+)        # label
      )?             # end of label
      >              # closing angle bracket
    ///g

    text = text.replace regex, (m, type, link, label) =>
      switch type

        when '@'
          if label then return "@#{label}"
          user = @dataStore.getUserById link
          if user
            return "@#{user.name}"

        when '#'
          if label then return "\##{label}"
          channel = @dataStore.getChannelById link
          if channel
            return "\##{channel.name}"

        when '!'
          if link in MESSAGE_RESERVED_KEYWORDS
            return "@#{link}"
          else if label
            return label
          return m

        else
          link = link.replace /^mailto:/, ''
          if label and -1 == link.indexOf label
            "#{label} (#{link})"
          else
            link

    text = text.replace /&lt;/g, '<'
    text = text.replace /&gt;/g, '>'
    text = text.replace /&amp;/g, '&'


  ###*
  # Flattens message text and attachments into a multi-line string
  ###
  flatten: (message) ->
    @warnForDeprecation
    text = []

    # basic text messages
    text.push(message.text) if message.text

    # append all attachments
    for attachment in message.attachments or []
      text.push(attachment.fallback)

    # flatten array
    text.join('\n')


  ###*
  # Formats an incoming Slack message
  ###
  incoming: (message) ->
    @warnForDeprecation
    @links @flatten message

  ###*
  # Logs the deprecation warning
  ###
  warnForDeprecation: () ->
    if (@robot)
        @robot.logger.warning "SlackFormatter is deprecated and will be removed in the next major version of " +
          "hubot-slack. This class was tightly coupled to the now-deprecated dataStore. Formatting functionality has " +
          "been moved to the SlackTextMessage class. If that class does not suit your needs, please file an issue " +
          "<https://github.com/slackapi/hubot-slack/issues>"

module.exports = SlackFormatter
