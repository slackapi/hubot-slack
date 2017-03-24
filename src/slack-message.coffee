{TextMessage} = require.main.require 'hubot'

class SlackTextMessage extends TextMessage
  # Represents a TextMessage created from the Slack adapter
  #
  # user       - The User object
  # text       - The parsed message text
  # rawText    - The unparsed message text
  # rawMessage - The Slack Message object
  constructor: (@user, @text, @rawText, @rawMessage) ->
    super @user, @text, @rawMessage.ts

module.exports = SlackTextMessage
