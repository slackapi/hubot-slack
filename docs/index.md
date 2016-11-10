---
layout: page
permalink: /
order: 0
headings:
    - title: Motivation
    - title: Requirements
    - title: Installation
    - title: Getting Help
---

So you want to get started with chatops using Hubot and Slack? We've got your covered. {{ site.product_name }} is an
adapter to let your connect your Hubot scripts to your Slack team, giving you and your fellow devops engineers 

## Requirements and Installation

Of course, you'll need Node.js, as well as NPM. NPM has
[a great tutorial](https://docs.npmjs.com/getting-started/installing-node) to help you get started if you don't have
these tools installed. [Yeoman](http://yeoman.io) is also a great tool for getting started on your first Hubot.

To install, you will first want to create a new Hubot project. The simplest way is to use your computer's terminal app
to invoke Yeoman.

```bash
npm install -g yo generator-hubot
```

This will install the Yeoman Hubot generator. Now we can create that Hubot project:

```bash
mkdir my-awesome-hubot && cd my-awesome-hubot
yo hubot --adapter=slack
```

This script will prompt you to describe the app you are going to build, and create a file that NPM can use to help
manage your project.

You will also need to set up a Custom Bot on your Slack team. This will create a token that your hubot can use to
log into your team as a bot. Visit the [Custom Bot creation page](https://my.slack.com/apps/A0F7YS25R-bots) to register
your bot with your Slack team, and to retrieve a new bot token

## Running Hubot

Once you've got your bot set up as you like, you can run your hubot with the run script included (being sure to
copy-and-paste your token in!):

```bash
HUBOT_SLACK_TOKEN=xoxb-YOUR-TOKEN-HERE ./bin/hubot --adapter slack
```

## Getting Help

If you get stuck, we're here to help. The following are the best ways to get assistance working through your issue:

  * [Issue Tracker](http://github.com/slackapi/{{ site.repo_name }}/issues) for reporting bugs or requesting features.
  * [dev4slack channel](https://dev4slack.slack.com/archives/{{ site.dev4slack_channel }}) for getting help using
  {{ site.product_name }} or just generally commiserating with your fellow developers.
