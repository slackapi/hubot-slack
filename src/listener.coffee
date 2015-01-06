{Listener} = require 'hubot'
{SlackRawMessage, SlackBotMessage} = require './message'

class SlackRawListener extends Listener
  # SlackRawListeners receive SlackRawMessages from the Slack adapter
  # and decide if they want to act on it.
  #
  # robot    - A Robot instance.
  # matcher  - A Function that determines if this listener should trigger the
  #            callback. The matcher takes a SlackRawMessage.
  # callback - A Function that is triggered if the incoming message matches.
  #
  # To use this listener in your own script, you can say
  #
  #     robot.listeners.push new SlackRawListener(robot, matcher, callback)
  constructor: (@robot, @matcher, @callback) ->

  # Public: Invokes super only for instances of SlackRawMessage
  call: (message) ->
    if message instanceof SlackRawMessage
      super message
    else
      false

class SlackBotListener extends Listener
  # SlackBotListeners receive SlackBotMessages from the Slack adapter
  # and decide if they want to act on it. SlackBotListener will only
  # match instances of SlackBotMessage.
  #
  # robot    - A Robot instance.
  # regex    - A Regex that determines if this listener should trigger the
  #            callback.
  # callback - A Function that is triggered if the incoming message matches.
  #
  # To use this listener in your own script, you can say
  #
  #     robot.listeners.push new SlackBotListener(robot, regex, callback)
  constructor: (@robot, @regex, @callback) ->
    @matcher = (message) =>
      if message instanceof SlackBotMessage
        message.match @regex

module.exports = {
  SlackRawListener
  SlackBotListener
}
