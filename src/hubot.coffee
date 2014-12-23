# Because we have hubot in our devDependencies, if these dependencies are
# installed, `require hubot` picks up the local version of hubot instead of the
# one the robot is running from. This means that our emitted `TextMessage`s
# won't trigger any `TextListener`s installed by scripts as that uses
# `instanceof` (which doesn't handle duplicate definitions).
#
# As a workaround, we can use `require.main.require 'hubot'` to require 'hubot'
# from the perspective of the "main" module. This will produce the correct
# version of hubot under normal circumstances. This should only fail if hubot
# is being used as a component of a larger application (even though it's not
# designed to work that way).

try
  module.exports = require.main.require 'hubot'
catch
  # If that failed, we'll assume it's because it couldn't find the hubot module.
  # In that event, let's just fall back to a normal require.
  module.exports = require 'hubot'
