{Adapter,TextMessage} = require 'hubot'

class Slack extends Adapter
   send: (envelope, strings...) ->
      user = @userFromParams(params)
      @bot.sendMessage user.room, str for str in strings

   reply: (envelope, strings...) ->
      user = @userFromParams(params)
      strings.forEach (str) =>
         @send params, "#{user.name}: #{str}"

   userFromParams: (params) ->
      # hubot < 2.4.2: params = user
      # hubot >= 2.4.2: params = {user: user, ...}
      if params.user then params.user else params

   run: ->
      self = @

      options =
         token:   process.env.HUBOT_SLACK_TOKEN
         team:    process.env.HUBOT_SLACK_TEAM
         name:    process.env.HUBOT_SLACK_BOTNAME

      # Create bot here

      self.emit "connected"

exports.use = (robot) ->
   new Slack robot