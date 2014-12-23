{Message, TextMessage} = require 'hubot'

# Hubot only started exporting Message in 2.11.0. Previous version do not export
# this class. In order to remain compatible with older versions, we can pull the
# Message class from TextMessage superclass.
if not Message
  Message = TextMessage.__super__.constructor

class SlackTextMessage extends TextMessage
  # Represents a TextMessage created from the Slack adapter
  #
  # user       - The User object
  # text       - The parsed message text
  # rawText    - The unparsed message text
  # rawMessage - The Slack Message object
  constructor: (@user, @text, @rawText, @rawMessage) ->
    super @user, @text, @rawMessage.ts

class SlackRawMessage extends Message
  # Represents Slack messages that are not suitable to treat as text messages.
  # These are hidden messages, or messages that have no text / attachments.
  #
  # Note that the `user` property may be a "fake" user, i.e. one that does not
  # exist in Hubot's brain and that contains little to no data.
  #
  # user       - The User object
  # text       - The parsed message text, if any, or ""
  # rawText    - The unparsed message text, if any, or ""
  # rawMessage - The Slack Message object
  constructor: (@user, @text = "", @rawText = "", @rawMessage) ->
    super @user

class SlackBotMessage extends SlackRawMessage
  # Represents a message sent by a bot. Specifically, this is any message
  # with the subtype "bot_message". Expect the `user` property to be a
  # "fake" user.

  # Determines if the message matches the given regex.
  #
  # regex - A Regex to check.
  #
  # Returns a Match object or null.
  match: (regex) ->
    @text.match regex

  # String representation of a SlackBotMessage
  #
  # Returns the message text
  toString: () ->
    @text

module.exports = {
  SlackTextMessage
  SlackRawMessage
  SlackBotMessage
}
