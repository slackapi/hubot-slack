SlackBot = require './src/bot'

exports.use = (robot) ->
  options = token: process.env.HUBOT_SLACK_TOKEN
  try
    options.rtm = JSON.parse(process.env.HUBOT_SLACK_RTM_CLIENT_OPTS)
  catch
  try
    options.rtmStart = JSON.parse(process.env.HUBOT_SLACK_RTM_START_OPTS)
  catch
  new SlackBot robot, options
