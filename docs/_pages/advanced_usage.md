---
layout: page
title: Advanced Usage
permalink: /advanced_usage
order: 5
headings:
    - title: Customizing rtm.start options
    - title: Customizing the RTM Client
    - title: Activate logging for debugging
    - title: Running Hubot behind an HTTP Proxy
    - title: Accessing more API methods and distribution
---

## Customizing rtm.start options

Under the hood, each Hubot using this adapter is connected to Slack using the [RTM API](https://api.slack.com/rtm). A
connection to the RTM API is initiated using [`rtm.start`](https://api.slack.com/methods/rtm.start).
By default, the adapter calls this method with only the required `token` parameter. If you have more specialized needs,
such as opting into MPIM data, you can add additional parameters to that Web API call by setting an environment
variable. The variable is called `HUBOT_SLACK_RTM_START_OPTS`, and its value should be a JSON-encoded string with
the additional parameters as key-value pairs. Here is an example of running hubot with that environment variable set:

```
$ HUBOT_SLACK_TOKEN=xoxb-xxxxx HUBOT_SLACK_RTM_START_OPTS='{ "mpim_aware": true }' ./bin/hubot --adapter slack
```

## Customizing the RTM Client

The RTM connection is handled by the `RtmClient` class from our handy
**Slack Developer Kit for Node.js version 3**. By default, the adapter instantiates the client with the required
`token` parameter, but more options are available. You can customize the options for the `RtmClient` instance by setting
an environment variable. The variable is called `HUBOT_SLACK_RTM_CLIENT_OPTS`, and its value should be a JSON-encoded
string with the additional parameters as key-value pairs. Note that not every option can only be set to JSON-encodable
values; you won't be able to create an instance of `SlackDataStore` and pass it in via a JSON string but you can set the
option to `false` to opt out of using a Data Store (not recommended). Here is an example of running hubot with a custom
retry configuration:

```
$ HUBOT_SLACK_TOKEN=xoxb-xxxxx HUBOT_SLACK_RTM_CLIENT_OPTS='{ "retryConfig": { "retries": 20 } }' ./bin/hubot --adapter slack
```

## Activate logging for debugging

Hubot has a flag for setting a log level, called `HUBOT_LOG_LEVEL`. This adapter peforms all of its logging through
Hubot, so setting it to its most detailed level, `debug`, can give you much more detailed information about activity
at runtime. Here is an example of running hubot with its log level set to `debug`:

```
$ HUBOT_SLACK_TOKEN=xoxb-xxxxx HUBOT_LOG_LEVEL=debug ./bin/hubot --adapter slack
```

The underlying **Slack Developer Kit for Node.js** can also be supplied with a log level to get _even more_ information
at runtime. Here is an example of combining both of these options:

```
$ HUBOT_SLACK_TOKEN=xoxb-xxxxx HUBOT_LOG_LEVEL=debug HUBOT_SLACK_RTM_CLIENT_OPTS='{ "logLevel": "debug" }' ./bin/hubot --adapter slack
```

## Accessing more API methods and distribution

You might find your Hubot unable to access a Web API method. For some methods, you can resolve this by transitioning
from an App Bot to a Custom Bot (these methods are [listed here](https://api.slack.com/bot-users#bot_methods)). If the
method isn't available to a Custom Bot, you'll have to use an App Bot and also manage a new token.

You will also need to manage a new token if you're considering distributing your Hubot powered app in the App Directory.

Start by finding the new scope that your app will require. Required scopes are specified on the documentation for each
[Web API method](https://api.slack.com/methods). Add this scope to your app on the "OAuth and Permissions" page of your
app configuration. Once you save the changes, you need to install the app on your development workspace once again.

After installing the app and authorizing the new scope, you'll notice a new **OAuth Access Token** (begins with `xoxp`).
This is the new token that you'll need to manage. We recommend putting the new token in another environment variable,
and using it to initialize a new `WebClient` object, as described in
[Using the Slack Web API]({{ site.baseurl }}{% link _pages/basic_usage.md %}#{{ "Using the Slack Web API" | slugify }}). For
example, if you put the new token in an environment variable called `SLACK_OAUTH_TOKEN`, you'd simply change the
initialization of the `WebClient` object to the following:

```coffeescript
  web = new WebClient process.env.SLACK_OAUTH_TOKEN
```

## Running Hubot behind an HTTP Proxy

You might find the need to run Hubot inside a firewall, where the internet is only accessible via a specific proxy.
Have no fear, environment variable configuration is here. Just add the `https_proxy` environment variable to your
startup (we'll just do this on the command line for this example) with the address and authentication information of
your proxy.

```
$ https_proxy="http://user:pass@localhost:8888" HUBOT_SLACK_TOKEN=xoxb-xxxxx ./bin/hubot --adapter slack
```
