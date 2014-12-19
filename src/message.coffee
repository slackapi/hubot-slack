{TextMessage} = require 'hubot'

class SlackTextMessage extends TextMessage
  # Represents a TextMessage created from the Slack adapter
  #
  # user       - The User object
  # text       - The parsed message text
  # rawText    - The unparsed message text
  # rawMessage - The Slack Message object
  constructor: (@user, @text, @rawText, @rawMessage) ->
    super @user, @text, @rawMessage.ts

# For some reason Hubot doesn't export Message, but that's what we want to extend.
# As a workaround, let's grab TextMessage's superclass
Message = TextMessage.__super__.constructor
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
