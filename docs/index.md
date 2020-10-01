---
layout: page
permalink: /
order: 0
headings:
    - title: Basic Setup
    - title: Getting a Slack Token
    - title: Running Hubot
    - title: Trick it out
    - title: Getting Help
---

So you want to get started using Hubot and Slack? We've got you covered. {{ site.product_name }} is an
adapter that connects your Hubot scripts to your Slack team, giving you and your fellow teammates a new best friend:
your very own scriptable, pluggable bot.

[What is Hubot and when should I use it?](https://hubot.github.com/) In short, it makes developing ChatOps-style bots
quicker and easier. It's an application you host on a server that uses the Slack platform and behaves however you
script it to.

## Basic Setup

To get started, you'll need [Node.js](https://nodejs.org/en/) installed.

You will first want to create a new Hubot project. The simplest way is to use your computer's terminal app to install
[Yeoman](http://yeoman.io), a handy tool that builds projects from a template. We'll also install the the template for
Hubot projects, `generator-hubot`.

```
npm install -g yo generator-hubot
```

Now we can create that Hubot project:

```
mkdir my-awesome-hubot && cd my-awesome-hubot
yo hubot --adapter=slack
```

Yeoman will ask you a few easy questions about your project and fill your directory with a Hubot app, ready to run.

## Getting a Slack Token

Next, you'll need a token from Slack to authenticate your Hubot. Use one of the following choices:

- **Create a [Classic Slack App](https://api.slack.com/authentication/migration#classic) with a Bot User (recommended)**: Slack apps are a container for many capabilities in the Slack platform, and let you access those capabilities in a single place. This is the recommended choice because it allows room for your Hubot to grow. To begin, you just need a Bot User.

    1. Create a new [Classic Slack app](https://api.slack.com/authentication/migration#classic) at the [app management page](https://api.slack.com/apps?new_classic_app=1). Pick a clever name and choose the workspace you want Hubot installed in.
    2. Navigate to the Bot User page and add a bot user. The display name is the name your team will use to mention your Hubot in Slack.
    3. Navigate to the Install App page and install the app into the workspace. Once you've authorized the installation, you'll be taken back to the Install App page, but this time you'll have a **Bot OAuth Access Token**. Copy that value, it will be your Slack token.

    **⚠️** Although the admin page encourages you to upgrade your app's OAuth scope, please do not do so. The latest permission model does not support the RTM API, which is the underlying API of the Hubot adapter.

- **Create a configuration of the Hubot Integration**: The [Hubot Integration](https://my.slack.com/apps/A0F7XDU93-hubot) is an older way to use the Slack platform. Its main advantage is that you get more permissions out of the box. For those concerned with security, this may be undesirable and should be taken into consideration. 

From the link above, click Install, choose a username, and finish by clicking Add Hubot Integration. On the following page, you'll see an **API Token**. Copy that value, as it will be your Slack token.

## Running Hubot

Run the command below, pasting your own Slack token after the `=`.

```
HUBOT_SLACK_TOKEN=xoxb-YOUR-TOKEN-HERE ./bin/hubot --adapter slack
```

Before you can interact with your Hubot, you invite it into a channel (shortcut: `/invite @username`).

_Windows users_: The above command sets an environment variable correctly for Linux and macOS, but
[Windows is a little different](https://hubot.github.com/docs/deploying/windows/).

## Trick it out

Hubot has many pre-written scripts that you can easy add by naming them in `external-scripts.json`. Take a look at all
the possibilites with the [hubot-scripts keyword in npm](https://www.npmjs.com/search?q=keywords:hubot-scripts).

Feeling inspired? You can jump into writing your own scripts by modifying `scripts/example.coffee`. It had tons of
helpful comments to guide you. You might also find the [Hubot scripting docs](https://hubot.github.com/docs/scripting/)
useful.

## Getting Help

If you get stuck, we're here to help. The following are the best ways to get assistance working through your issue:

  * [Issue Tracker](http://github.com/slackapi/{{ site.repo_name }}/issues) for reporting bugs or requesting features.

  * [Bot Developer Hangout](https://community.botkit.ai) is a Slack community for developers building all types of bots.
    You can find the maintainers and users of this package in **#slack-api.**

  * Email us in Slack developer support: [developers@slack.com](mailto://developers@slack.com)
