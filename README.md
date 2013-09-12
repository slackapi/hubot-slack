# hubot-slack

This is a [Hubot](http://hubot.github.com/) adapter to use with [Slack](https://slack.com).

## Quickstart: Hubot for Slack on Heroku

First, read and understand the [instructions on the Hubot wiki](https://github.com/github/hubot/blob/master/docs/deploying/heroku.md). You will be following those instructions, with the following modifications:

1. Edit `package.json` and add `hubot-slack` to the `dependencies` section.
1. Edit `Procfile` and change it to use the `slack` adapter:

        web: bin/hubot --adapter slack

1. Activate the Hubot service on your "Team Services" page inside Slack.
1. Configure your Hubot install using the variables displayed on the Hubot Team Service page. Examples:

        % heroku config:add HEROKU_URL=http://soothing-mists-4567.herokuapp.com
        % heroku config:add HUBOT_SLACK_TOKEN=dqqQP9xlWXAq5ybyqKAU0axG
        % heroku config:add HUBOT_SLACK_TEAM=myteam
        % heroku config:add HUBOT_SLACK_BOTNAME=slackbot

1. Follow the rest of the Hubot instructions to get up-and-running.

## Adapter configuration

This adapter uses the following environment variables:

### HUBOT\_SLACK\_TOKEN

This is the service token you are given when you add Hubot to your Team Services.

### HUBOT\_SLACK\_TEAM

This is your team's Slack subdomain. For example, if your team is `https://myteam.slack.com/`, you would enter `myteam` here.

### HUBOT\_SLACK\_BOTNAME

Optional. What your Hubot is called on Slack. If you entered `slackbot` here, you would address your bot like `slackbot: help`. Otherwise, defaults to `hubot`.
