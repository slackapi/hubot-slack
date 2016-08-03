# [slack-hubot] Changelog

### v4.0.2 (2016-08-03)
  * v4 shipped with this amazing feature whereby we would silently destroy any non-string fields in a message object before sending it out. Y'all loved that feature so much, we just had to build on it. Now we silently destroy you entire message object before sending it out. J/K, that was actually a bug, and we fixed it.

### v4.0.1 (2016-07-19)
  * Usernames with `-` and `.` no longer borked
  * You could craft a bot that would crash Hubot by simply having it send a message. Wow! That got fixed.

### v4.0.0 (2016-07-15)

  * Now uses the latest version of `node-slack-sdk` (v3.4.1 as of this writing), inheriting all the improvements therein.
  * Better (and automatically enabled) reconnect logic. As in, it actually reconnects automatically at all.
  * Now you can upload files!
  * Significantly improved handling of messages with attachments, which is to say, we can deliver them.
  * Message formatting of links, usernames and channel names is now working far better than it ever did, which is damning with faint praise, but hey.
  * Long messages are now left for Slack to handle, bless their hearts.
  * Slack usernames with `.` and `-` are now treated with the respect and dignity due to all usernames.
  * Messages from bots are no longer filtered out, which is both cool and potentially terrifying, but we should never have silenced the robots in the first place.
  * Remember how if you tried to hack on this adapter and used `npm link` to plug that into a live bot? And how that didn't work? Yeah? Well now it does. Stupid `instanceof`.
  * Total refactoring of the functionality, exposing a slightly different interface. So watch out for that.
  * You can now access the underlying Slack client directly, for when you really need low-level functionality therein.
