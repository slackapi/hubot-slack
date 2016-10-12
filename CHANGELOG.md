# [slack-hubot] Changelog

### v4.2.1 (2016-10-120
  * Please don't ask. A bug. A tiny bug. But not here. In NPM. *sigh*

### v4.2.0 (2016-10-12)
  * And now we have an even easier way of watching for message reactions

### v4.1.0 (2016-09-21)
  * Somewhere out there, someone has been pining to handle message reactions. If that someone is you, this release lets you do that. Preprare to receive new `ReactionMessage` messages when reactions are added or removed from messages! To the rest of you: Carry on.

### v4.0.5 (2016-09-14)
  * Sometimes you could send a message to an @username or a #channelname, but most of the time you couldn't. We have found the problem, and politely asked it to leave.

### v4.0.4 (2016-09-12)
  * Oh, so it turns out that the solution to using Slack's message formatting was incorrectly conceived. Fixed.

### v4.0.3 (2016-09-12)
  * So, you know how Hubot would crash when you tried to set the topic in a private channel? Yeah, me too. Fixed. (#350)
  * As it happens, we were taking on some of the message formatting work that the Slack servers can do on our behalf. Fixed. (#236, #356)
  * `robot.messageRoom` now accepts room names, not just IDs. Because sometimes all you have is a name. (#346)
  * Treely ruly ignore all self-generated messages, for realz this time.
  * Send all messages with `as_user=true` by default now.
  

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
