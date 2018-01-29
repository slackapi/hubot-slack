{ Robot } = require.main.require 'hubot'
{ ReactionMessage } = require './message';

###*
# Adds a Listener for ReactionMessages with the provided matcher, options, and callback
# @public
# @param {Function} [matcher] - a function to determine if the listener should run. must return something
# truthy if it should and that value with be available on `response.match`.
# @param {Object} [options] - an object of additional parameters keyed on extension name.
# @param {Function} callback - a function that is called with a Response object if the matcher function returns true
###
Robot::react = (matcher, options, callback) ->
  matchReaction = (msg) -> msg instanceof ReactionMessage

  if arguments.length == 1
    return @listen matchReaction, matcher

  else if matcher instanceof Function
    matchReaction = (msg) -> msg instanceof ReactionMessage && matcher(msg)

  else
    callback = options
    options = matcher

  @listen matchReaction, options, callback
