SlackBot = require './src/slack'
{SlackTextMessage, SlackRawMessage, SlackBotMessage} = require './src/message'
{SlackRawListener, SlackBotListener} = require './src/listener'

module.exports = exports = {
  SlackBot
  SlackTextMessage
  SlackRawMessage
  SlackBotMessage
  SlackRawListener
  SlackBotListener
}

exports.use = (robot) ->
  new SlackBot robot
