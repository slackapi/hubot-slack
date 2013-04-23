# hubot-slack

This is a [Hubot](http://hubot.github.com/) adapter to use with your Slack.

## Quickstart: Hubot for Slack on Heroku

First, read and understand the [instructions on the Hubot wiki](https://github.com/github/hubot/wiki/Deploying-Hubot-onto-Heroku). You will be following those instructions, with the following modifications:

1. Edit `package.json` and add `hubot-slack` to the `dependencies` section.
1. Edit `Procfile` and change it to use the `slack` adapter:

    web: bin/hubot --adapter hipchat

1. Activate the Hubot service on your Slack's "Team Services" page.
1. Configure your Hubot install using the variables displayed on the Hubot Team Service page. Examples:

    % heroku config:add HEROKU_URL=http://soothing-mists-4567.herokuapp.com
    % heroku config:add HUBOT_SLACK_TOKEN=foo
    % heroku config:add HUBOT_SLACK_TEAM=tinyspeck
    % heroku config:add HUBOT_SLACK_BOTNAME=slackbot

1. Follow the rest of the Hubot instructions to get up-and-running.

## Adapter configuration

This adapter uses the following environment variables:

### HUBOT\_SLACK\_TOKEN

This is the service token you are given when you add Hubot to your Team Services.

### HUBOT\_SLACK\_TEAM

This is the subdomain of your team's slack, so we know where to find you. For example, if your team is `https://foo.slack.com/`, you would enter `foo` here.

### HUBOT\_SLACK\_BOTNAME

Optional. What your Hubot is called on Slack. If you entered `slackbot` here, you would address your bot like `slackbot: help`. Otherwise, defaults to `hubot`.
