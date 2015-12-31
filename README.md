# hubot-slack

This is a [Hubot](http://hubot.github.com/) adapter to use with [Slack](https://slack.com).

[![Build Status](https://travis-ci.org/slackhq/hubot-slack.png)](https://travis-ci.org/slackhq/hubot-slack)

## Getting Started

#### Creating a new bot

- `npm install -g hubot coffee-script yo generator-hubot`
- `mkdir -p /path/to/hubot`
- `cd /path/to/hubot`
- `yo hubot`
- `npm install hubot-slack --save`
- Initialize git and make your initial commit
- Check out the [hubot docs](https://github.com/github/hubot/tree/master/docs) for further guidance on how to build your bot

#### Testing your bot locally

- `HUBOT_SLACK_TOKEN=xoxb-1234-5678-91011-00e4dd ./bin/hubot --adapter slack`

#### Deploying to Heroku

This is a modified set of instructions based on the [instructions on the Hubot wiki](https://github.com/github/hubot/blob/master/docs/deploying/heroku.md).

- Follow the instructions above to create a hubot locally

- Install [heroku toolbelt](https://toolbelt.heroku.com/) if you haven't already.
- `heroku create my-company-slackbot`
- `heroku addons:create rediscloud:30`
- Activate the Hubot service on your ["Team Services"](http://my.slack.com/services/new/hubot) page inside Slack.
- Add the [config variables](#configuration). For example:

        % heroku config:add HEROKU_URL=https://my-company-slackbot.herokuapp.com
        % heroku config:add HUBOT_SLACK_TOKEN=xoxb-1234-5678-91011-00e4dd

- Deploy the bot:

        % git push heroku master

- Profit!

## Upgrading from earlier versions of Hubot

Version 3 of the hubot-slack adapter requires different server support to
previous versions. If you have an existing "hubot" integration set up you'll
need to upgrade:

- Go to https://my.slack.com/services/new/hubot and create a new hubot
  integration
- Run `npm install hubot-slack --save`
  to update your code.
- Test your bot locally using:
  `HUBOT_SLACK_TOKEN=xoxb-1234-5678-91011-00e4dd ./bin/hubot --adapter slack`
- Update your production startup scripts to pass the new `HUBOT_SLACK_TOKEN`.
  You can remove the other `HUBOT_SLACK_*` environment variables if you want.
- Deploy your new hubot to production.
- Once you're happy it works, disable the old hubot integration from
  https://my.slack.com/services

## Configuration

This adapter uses the following environment variables:

 - `HUBOT_SLACK_TOKEN` - this is the API token for the Slack user you would like to run Hubot under.

To add or remove your bot from specific channels or private groups, you can use the /kick and /invite slash commands that are built into Slack.

If you have scripts that send notifications to specific channels, use the channel name ie. `HUBOT_TWITTER_MENTION_ROOM="#general"` Keep in mind that your bot needs to be joined to your specific channels by the /invite slash command.

If you're using the [hubot-auth](https://github.com/hubot-scripts/hubot-auth/) script, you can get the user IDs required for the `HUBOT_AUTH_ADMIN` setting by calling the [users.list API method](https://api.slack.com/methods/users.list/test).

## Copyright

Copyright &copy; Slack Technologies, Inc. MIT License; see LICENSE for further details.
