# hubot-slack

### Important Notice

**The original hubot-slack is no longer under active development.** Slack recommends taking a look at [Bolt for JS with Socket Mode](https://slack.dev/bolt-js/concepts#socket-mode) first if you're getting started.

But I'm going to maintain this fork as I continue to evolve Hubot. So feel free to use this one.

## Installation

```sh
npm i @hubot-friends/hubot-slack hubot
```

This is a [Hubot](http://hubot.github.com/) adapter to use with [Slack](https://slack.com).

Comprehensive documentation [is available](https://slackapi.github.io/hubot-slack).

## Adapter Configuration

- Create (or use an existing one) a [Slack Workspace](https://slack.com/get-started#/createnew)
- Create a [Slack App](https://api.slack.com/apps)
- Create an App-Level Token and give it `connections:write` scope. This will be the `HUBOT_SLACK_APP_TOKEN` environment variable. The adapter will use this token to authenticate via Slacks Socket Mode (WebSockets)
- Create a [Bot Token](https://api.slack.com/authentication/token-types#bot). This will be the `HUBOT_SLACK_BOT_TOKEN` environment variable. The adapter will use this token to POST messages to Slack's HTTP API.
- Make sure to give the Slack App the scope permissions noted below in "Notes on using SocketMode".

## Startup

An example command to start the app on MacOS is the following. Assuming there is a file called `.env` with the following environment variables set:

```sh
HUBOT_SLACK_APP_TOKEN=xapp-1-...
HUBOT_SLACK_BOT_TOKEN=xoxb-...
```

Set the environment variables to the values you created for your Slack Apps App-Level Token (`HUBOT_SLACK_APP_TOKEN`) and Bot Token (`HUBOT_SLACK_BOT_TOKEN`).

```sh
env $(cat .env | grep -v \"#\" | xargs -0) PORT=8080 hubot -a @hubot-friends/hubot-slack -n mybot
```

Another way to start the app in MacOS or Linux is:

```sh
HUBOT_SLACK_APP_TOKEN=xapp-1... HUBOT_SLACK_BOT_TOKEN=xoxb-... PORT=8080 hubot -a @hubot-friends/hubot-slack -n mybot
```

# Notes on using SocketMode

Need the following permissions:
- app_mentions:read
- channels:join
- channels:history
- channels:read
- chat:write
- im:write
- im:history
- im:read
- users:read
- groups:history
- groups:write
- groups:read
- mpim:history
- mpim:write
- mpim:read

Need to following events:
- app_mention
- message.channels
- message.im
- message.groups
- message.mpim

## Sample YAML
The following YAML manifest will work.

```yaml
display_information:
  name: NameOfYourBot
  description: Description of your bot.
  background_color: "#3d001d"
features:
  app_home:
    home_tab_enabled: false
    messages_tab_enabled: true
    messages_tab_read_only_enabled: false
  bot_user:
    display_name: NameOfYourbot
    always_online: true
oauth_config:
  scopes:
    bot:
      - app_mentions:read
      - channels:join
      - channels:history
      - channels:read
      - chat:write
      - im:write
      - im:history
      - im:read
      - users:read
      - groups:history
      - groups:write
      - groups:read
      - mpim:history
      - mpim:write
      - mpim:read
settings:
  event_subscriptions:
    bot_events:
      - app_mention
      - message.channels
      - message.im
      - message.groups
      - message.mpim
  interactivity:
    is_enabled: true
  org_deploy_enabled: false
  socket_mode_enabled: true
  token_rotation_enabled: false
```