---
layout: page
title: Advanced Usage
permalink: /advanced_usage
order: 5
headings:
    - title: Customizing rtm.start options
    - title: Customizing the RTM Client
---

## Customizing rtm.start options

Under the hood, each Hubot using this adapter is connected to Slack using the [RTM API](https://api.slack.com/rtm). A
connection to the RTM API is initiated using the Web API method [`rtm.start`](https://api.slack.com/methods/rtm.start).
By default, the adapter calls this method with only the required `token` parameter. If you have more specialized needs,
such as opting into MPIM data, you can add additional parameters to that Web API call by setting an environment
variable. The variable is called `HUBOT_SLACK_RTM_START_OPTS`, and its value should be a JSON-encoded string with
the additional parameters as key-value pairs. Here is an example of running hubot with that environment variable set:

```
$ HUBOT_SLACK_TOKEN=xoxb-xxxxx HUBOT_SLACK_RTM_OPTIONS='{ "mpim_aware": true }' bin/hubot --adapter slack
```

## Customizing the RTM Client

The RTM connection is handled by the `RtmClient` implementation from our handy
[Slack SDK for Node](https://github.com/slackapi/node-slack-sdk). By default, the adapter instantiates the client with
only the required `token` parameter, but many more are
[available in the documentation](https://slackapi.github.io/node-slack-sdk/reference/RTMClient#new_RTMClient_new). You
can customize the options for the `RtmClient` instance by setting an environment variable. The variable is called
`HUBOT_SLACK_RTM_CLIENT_OPTS` and its value should be a JSON-encoded string with the additional parameters as key-value
pairs. Note that not every option can only be set to JSON-encodable values; you won't be able to create an instance of
`SlackDataStore` and pass it in via a JSON string but you can set the option to `false` to opt out of using a Data Store
(not recommended). Here is an example of running hubot with a custom retry configuration:

```
$ HUBOT_SLACK_TOKEN=xoxb-xxxxx HUBOT_SLACK_RTM_CLIENT_OPTS='{ "retryConfig": { "retries": 20 } }' bin/hubot --adapter slack
```
