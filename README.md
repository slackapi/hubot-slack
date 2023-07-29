# hubot-slack

### Important Notice

**The original hubot-slack is no longer under active development.** Slack recommands taking a look at [Bolt for JS with Socket Mode](https://slack.dev/bolt-js/concepts#socket-mode) first if you're getting started.

But I'm going to maintain this fork as I continue to evolve Hubot. So feel free to use this one.

## Installation

```sh
npm i @hubot-friends/hubot-slack
```

This is a [Hubot](http://hubot.github.com/) adapter to use with [Slack](https://slack.com).

Comprehensive documentation [is available](https://slackapi.github.io/hubot-slack).


# Notes on using SocketMode

Need the following permissions:
- app_mentions:read
- channels:join
- chat:write
- im:write

Need the following *Bot Token Scopes*:
- users:read
