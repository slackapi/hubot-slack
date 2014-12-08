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
- Edit your `Procfile` and change it to use the `slack` adapter:

        web: bin/hubot --adapter slack

- Install [heroku toolbelt](https://toolbelt.heroku.com/) if you haven't already.
- `heroku create my-company-slackbot`
- `heroku addons:add redistogo:nano`
- Activate the Hubot service on your ["Team Services"](http://my.slack.com/services/new/hubot) page inside Slack.
- Add the [config variables](#adapter-configuration). For example:

        % heroku config:add HEROKU_URL=http://my-company-slackbot.herokuapp.com
        % heroku config:add HUBOT_SLACK_TOKEN=xoxb-1234-5678-91011-00e4dd

- Deploy and start the bot:

        % git push heroku master
        % heroku ps:scale web=1

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
- Once you're happy it works, remove the old hubot integration from
  https://my.slack.com/services

## Adapter configuration

This adapter uses the following environment variables:

 - `HUBOT_SLACK_TOKEN` - this is the API token for the Slack user you would like to run Hubot under.

## Copyright

Copyright &copy; Slack Technologies, Inc. MIT License; see LICENSE for further details.
