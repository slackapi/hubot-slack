# hubot-slack

This is a [Hubot](http://hubot.github.com/) adapter to use with [Slack](https://slack.com).  
[![Build Status](https://travis-ci.org/tinyspeck/hubot-slack.png)](https://travis-ci.org/tinyspeck/hubot-slack)

## Getting Started

#### Creating a new bot

- `npm install -g hubot coffee-script`
- `hubot --create [path_name]`
- `cd [path_name]`
- `npm install hubot-slack --save`
- Initialize git and make your initial commit
- Check out the [hubot docs](https://github.com/github/hubot/tree/master/docs) for further guidance on how to build your bot

#### Testing your bot locally

- `./bin/hubot`

#### Deploying to Heroku

This is a modified set of instructions based on the [instructions on the Hubot wiki](https://github.com/github/hubot/blob/master/docs/deploying/heroku.md).

- Make sure `hubot-slack` is in your `package.json` dependencies
- Edit your `Procfile` and change it to use the `slack` adapter:

        web: bin/hubot --adapter slack

- Install [heroku toolbelt](https://toolbelt.heroku.com/) if you haven't already.
- `heroku create my-company-slackbot`
- `heroku addons:add redistogo:nano`
- Activate the Hubot service on your ["Team Services"](http://my.slack.com/services/new/hubot) page inside Slack.
- Add the [config variables](#adapter-configuration). For example:

        % heroku config:add HEROKU_URL=http://soothing-mists-4567.herokuapp.com
        % heroku config:add HUBOT_SLACK_TOKEN=dqqQP9xlWXAq5ybyqKAU0axG
        % heroku config:add HUBOT_SLACK_TEAM=myteam
        % heroku config:add HUBOT_SLACK_BOTNAME=slack-hubot

- Deploy and start the bot:

        % git push heroku master
        % heroku ps:scale web=1

- Profit!

## Adapter configuration

This adapter uses the following environment variables:

#### HUBOT\_SLACK\_TOKEN

This is the service token you are given when you add Hubot to your Team Services.

#### HUBOT\_SLACK\_TEAM

This is your team's Slack subdomain. For example, if your team is `https://myteam.slack.com/`, you would enter `myteam` here.

#### HUBOT\_SLACK\_BOTNAME

Optional. What your Hubot is called on Slack. If you entered `slack-hubot` here, you would address your bot like `slack-hubot: help`. Otherwise, defaults to `slackbot`.

#### HUBOT\_SLACK\_CHANNELMODE

Optional. If you entered `blacklist`, Hubot will not post in the rooms specified by HUBOT_SLACK_CHANNELS, or alternately *only* in those rooms if `whitelist` is specified instead. Defaults to `blacklist`.

#### HUBOT\_SLACK\_CHANNELS

Optional. A comma-separated list of channels to either be blacklisted or whitelisted, depending on the value of HUBOT_SLACK_CHANNELMODE.

#### HUBOT\_SLACK\_LINK\_NAMES

Optional. By default, Slack will not linkify channel names (starting with a '#') and usernames (starting with an '@'). You can enable this behavior by setting HUBOT_SLACK_LINK_NAMES to 1. Otherwise, defaults to 0. See [Slack API : Message Formatting Docs](https://api.slack.com/docs/formatting) for more information.

## Under the Hood

#### Receiving Messages:

The slack adapter adds a path to the robot's router that will accept POST requests to:

`/hubot/slack-webhook`

Source: [https://github.com/tinyspeck/hubot-slack/blob/2.1.0/src/slack.coffee#L149-L165](https://github.com/tinyspeck/hubot-slack/blob/2.1.0/src/slack.coffee#L149-L165)

Expected parameters:

- text
- user_id
- user_name
- channel_id
- channel_name

If there is a message and it can deduce an author from those paramters, it'll create a new [TextMessage](https://github.com/github/hubot/blob/v2.7.2/src/message.coffee#L14) object and have the robot receive it, from there proceeding down the regular hubot path.

#### Sending Messages

When a script calls `send()` or `reply()` this adapter makes a POST request to your team's specific URL webhook:

`https://<your_team_name>.slack.com/services/hooks/hubot`

with a JSON-formatted body including the following dictionary:

- username
- channel
- text
- link_names (optionally)

#### Message to a specific room:

Sometime, it's useful to send a message regardless of the channel's activity (like `robot.hear` or `robot.response`). Hubot has [`robot.messageRoom`](https://github.com/github/hubot/blob/v2.8.0/src/robot.coffee#L401-L409) available for this use case.

Slack API uses channel ID's by default, which uses computer-friendly alphanumeric ID. To use the pretty names, prefix it with a hash.

```coffeescript
robot.respond /hello$/i, (msg) ->
  robot.messageRoom '#general', 'hello there'
```
