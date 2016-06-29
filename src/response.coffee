{Response} = require 'hubot'

class SlackResponse extends Response

  sendCustom: (data) ->
    data.message = @envelope.message
    @robot.adapter.customMessage data

module.exports = SlackResponse
