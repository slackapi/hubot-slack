{Robot}           = require.main.require "hubot"
{ReactionMessage, PresenceMessage} = require "./message"

###*
# Adds a Listener for ReactionMessages with the provided matcher, options, and callback
#
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

###*
# Adds a Listener for PresenceMessages with the provided matcher, options, and callback
#
# @public
# @param {Function} [matcher] - A Function that determines whether to call the callback.
# Expected to return a truthy value if the callback should be executed (optional).
# @param {Object} [options]  - An Object of additional parameters keyed on extension name (optional).
# @param {Function} callback - A Function that is called with a Response object if the matcher
# function returns true.
###
Robot::presenceChange = (matcher, options, callback) ->
  matchPresence = (msg) -> msg instanceof PresenceMessage

  if arguments.length == 1
    return @listen matchPresence, matcher

  else if matcher instanceof Function
    matchPresence = (msg) -> msg instanceof PresenceMessage && matcher(msg)

  else
    callback = options
    options = matcher

  @listen matchPresence, options, callback

# NOTE: extend Response type with a method for creating a new thread from the incoming message
