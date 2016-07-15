# [slack-hubot] Changelog

### v4.0.0 (2016-06-15)

  * Now uses the latest version of `node-slack-sdk` (v3.4.1 as of this writing), inheriting all the improvements therein.
  * Better (and automatically enabled) reconnect logic
  * Now you can upload files
  * Significantly improved handling of messages with attachments
  * Message formatting of links, usernames and channel names is now working far better than it ever did
  * Long messages are now left for Slack to handle (as it does)
  * Slack usernames with `.` and `-` are now respected
  * Messages from bots are no longer filtered out
  * Total rewrite of the functionality, expsoing a slightly different interface
