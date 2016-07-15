SlackBot = require './src/bot'

exports.use = (robot) ->
  new SlackBot robot, token: process.env.HUBOT_SLACK_TOKEN
