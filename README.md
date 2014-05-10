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
        % heroku config:add HUBOT_SLACK_TOKEN=xoxp-1234-5678-91011-00e4dd

- Deploy and start the bot:

        % git push heroku master
        % heroku ps:scale web=1

- Profit!

## Adapter configuration

This adapter uses the following environment variables:

#### HUBOT\_SLACK\_TOKEN

This is the API token for the Slack user you would like to run Hubot under.
