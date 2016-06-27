# Because we have hubot in our devDependencies, if these dependencies are
# installed, `require hubot` picks up the local version of hubot instead of the
# one the robot is running from. This means that our emitted `TextMessage`s
# won't trigger any `TextListener`s installed by scripts as that uses
# `instanceof` (which doesn't handle duplicate definitions).
#
# As a workaround, all requires of hubot are funneled through this module, and
# here we can mess with our module.paths to ensure our devDependency doesn't
# affect the loading of hubot.

Path = require 'path'

oldPaths = module.paths.splice(0) # make a copy
modRoot = Path.dirname __dirname
skipPath = Path.join modRoot, 'node_modules'
if (idx = module.paths.indexOf skipPath) >= 0
  module.paths.splice(idx, 1) # remove the path

try
  path = require.resolve 'hubot'
catch
  # If that failed, hopefully that means we're running tests.
  # The alternative is we may be `npm link`ed in instead of properly installed
  # and therefore cannot find the hubot.
  # In that event, let's walk our parent modules until we find something outside
  # our current directory.
  mod = module
  while mod = mod.parent
    continue if mod.filename.slice(0, modRoot.length+1) == "#{modRoot}/"
    break
  if mod
    # this is our first parent outside our module root
    # Sadly, require.resolve isn't exposed on module.require.
    # But we can hack it by swapping out our paths array.
    module.paths = mod.paths
    try
      path = require.resolve 'hubot'
    catch
      # That failed. At this point, let's hope this is because we're running the
      # test suite.
finally
  module.paths = oldPaths

if path
  module.exports = require path
else
  # Do a normal require with our original module paths. This will let our
  # devDependencies have a shot at fulfilling the requirement.
  module.exports = require 'hubot'
