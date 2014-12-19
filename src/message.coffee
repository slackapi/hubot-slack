{TextMessage} = require 'hubot'

class SlackTextMessage extends TextMessage
  # Represents a TextMessage created from the Slack adapter
  #
  # text - The parsed message text
  # rawText - The unparsed message text
  constructor: (@user, @text, @rawText, @id) ->
    super @user, @text, @id

# For some reason Hubot doesn't export Message, but that's what we want to extend.
# As a workaround, let's grab TextMessage's superclass
Message = TextMessage.__super__.constructor
class SlackRawMessage extends Message
  # Represents Slack messages that are not suitable to treat as text messages.
  # These are hidden messages, or messages that have no text / attachments.
  # All properties of the message are exposed from SlackRawMessage, except
  # as follows:
  # - user: This property corresponds to Message.user and is nominally a
  #         Hubot user. However, as many events don't actually have a user
  #         attached to them, this may be a "fake" user.
  # - text: If present, this is the parsed text. See `rawText`.
  # - rawText: If `text` is present, `rawText` contains the unparsed text.
  constructor: (user, @text, msg) ->
    for own k, v of (msg or {})
      switch
        when k[0] is '_' then # ignore properties starting with _
        when k is 'text' then @rawText = v
        else @[k] = v
    super user

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
