{Robot}           = require.main.require "hubot"
{ReactionMessage, PresenceMessage, FileSharedMessage, MeMessage} = require "./message"

# Requires the es2015 version of Hubot for v3 or higher so the correct prototype is updated
if Robot.name == "CoffeeScriptCompatibleClass"
  {Robot} = require.main.require "hubot/es2015"

###*
# Adds a Listener for ReactionMessages with the provided matcher, options, and callback
#
# @public
# @param {Function} [matcher] - a function to determine if the listener should run. must return something
# truthy if it should and that value with be available on `response.match`.
# @param {Object} [options] - an object of additional parameters keyed on extension name.
# @param {Function} callback - a function that is called with a Response object if the matcher function returns true
###
Robot::hearReaction = (matcher, options, callback) ->
  matchReaction = (msg) -> msg instanceof ReactionMessage

  if not options and not callback
    return @listen matchReaction, matcher

  else if matcher instanceof Function
    matchReaction = (msg) -> msg instanceof ReactionMessage && matcher(msg)

  else
    callback = options
    options = matcher

  @listen matchReaction, options, callback

###*
# Adds a Listener for MeMessages with the provided matcher, options, and callback
#
# @public
# @param {Function} [matcher] - a function to determine if the listener should run. must return something
# truthy if it should and that value with be available on `response.match`.
# @param {Object} [options] - an object of additional parameters keyed on extension name.
# @param {Function} callback - a function that is called with a Response object if the matcher function returns true
###
Robot::hearMeMessage = (matcher, options, callback) ->
  matchMeMessage = (msg) -> msg instanceof MeMessage

  if not options and not callback
    return @listen matchMeMessage, matcher

  else if matcher instanceof Function
    matchMeMessage = (msg) -> msg instanceof MeMessage && matcher(msg)

  else
    callback = options
    options = matcher

  @listen matchMeMessage, options, callback

###*
# DEPRECATED Adds a listener for ReactionMessages with the provided matcher, options, and callback.
#
# This method is deprecated in favor of Robot#hearReaction(), which is exactly the same, except with a clearer name.
#
# @deprecated
# @public
# @param {Function} [matcher] - a function to determine if the listener should run. must return something
# truthy if it should and that value with be available on `response.match`.
# @param {Object} [options] - an object of additional parameters keyed on extension name.
# @param {Function} callback - a function that is called with a Response object if the matcher function returns true
###
Robot::react = (matcher, options, callback) ->
  @logger.warning "Robot#react() is a deprecated method and will be removed in the next major version of " +
    "hubot-slack. It is recommended to use Robot#hearReaction() which behaves exactly the same, but has a clearer name."
  @hearReaction(matcher, options, callback)

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
  
###*
# Adds a Listener for FileSharedMessages with the provided matcher, options, and callback
#
# @public
# @param {Function} [matcher] - a function to determine if the listener should run. must return something
# truthy if it should and that value with be available on `response.match`.
# @param {Object} [options] - an object of additional parameters keyed on extension name.
# @param {Function} callback - a function that is called with a Response object if the matcher function returns true
###
Robot::fileShared = (matcher, options, callback) ->
  matchFileShare = (msg) -> msg instanceof FileSharedMessage

  if not options and not callback
    return @listen matchFileShare, matcher

  else if matcher instanceof Function
    matchFileShare = (msg) -> msg instanceof FileSharedMessage && matcher(msg)

  else
    callback = options
    options = matcher

  @listen matchFileShare, options, callback

# NOTE: extend Response type with a method for creating a new thread from the incoming message
