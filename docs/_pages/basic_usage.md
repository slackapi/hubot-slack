---
layout: page
title: Basic Usage
permalink: /basic_usage
order: 4
headings:
    - title: A note on handling tokens and other sensitive data
    - title: Listening for a message
    - title: Messages directed to your bot
    - title: Posting a response
    - title: Message reactions
    - title: General Web API patterns
---

Most Hubots are designed to react to user input&mdash;a user makes a request, and Hubot responds, often after going out
into the world to trigger some action (building your code, deploying to production, and so on). Many of the tasks
you'd like to accomplish are already well documented in the [official Hubot documentation](https://hubot.github.com/docs/).
Nevertheless, we'll cover the basics, as well as some interesting Slack-specific use cases.

Each of the examples below are ready to be included as a [Hubot script](https://hubot.github.com/docs/scripting/)
&mdash;just drop them into the `scripts` folder.

See [Tokens & Authentication]({{ site.baseurl | prepend: site.url }}/auth) for API token best practices.

--------

## Listening for a message

Most tasks with Hubot are no different with the Slack adapter than they are for other adapters.

You can listen for messages in any channel that your Hubot has been invited into very simply, by defining a regex
to match against. Any message that matches your regex will trigger the callback you assign to that regex.

```coffeescript
module.exports = (robot) ->

  robot.hear /badger/i, (res) ->
    robot.logger.debug "Received message #{res.message.text}"
```

--------

## Messages directed to your bot

If you want to specifically listen for messages that mention your bot, again the pattern here is no different than
for any other Hubot. You define a regex to match against. Any message that matches your regex _and_ either includes
an @-mention of your bot, or occurs within a DM with your bot will trigger the callback you assign to that regex.

```coffeescript
module.exports = (robot) ->

  robot.respond /badger/i, (res) ->
    robot.logger.debug "Received message #{res.message.text}"
```

--------

## Posting a response

Responding to a message is straightforward, regardless of whether the message was sent to your bot specifically or
to anyone in general.

```coffeescript
module.exports = (robot) ->

  robot.hear /badger/i, (res) ->
    res.send "Yes, more badgers please!"
```

--------

## Message reactions

Of course, Slack is more than just text message. Users can post emoji responses to messages as well—and your bot can both
listen for these, and post reactions of its own. Here is a simple recipe to listen for message reactions, and to add
the same reaction back to the same message

```coffeescript
module.exports = (robot) ->

  robot.react (res) ->
    robot.logger.debug res.message.type, res.message.reaction
    if res.message.type == "added"
      robot.adapter.client.web.reactions.add(res.message.reaction, {channel: res.message.item.channel, timestamp: res.message.item.ts})

```

--------

## General Web API patterns

You can access much of the [Slack Web API](https://api.slack.com/bot-users#api_usage) with your bot. The `robot`
object uses [Slack Developer Kit for Node.js](slackapi.github.io/node-slack-sdk/) to access the Slack API, and an instance of the
Web API wrapper is available in `robot.client.web`. So, you can call API endpoints in the following way:

```coffeescript
module.exports = (robot) ->

  robot.hear /test/i, (res) ->
    robot.adapter.client.web.api.test() # call `api.test` endpoint
    
    # There are better ways to post messages of course
    # Notice the _required_ arguments `channel` and `text`, and the _optional_ arguments `as_user`, and `unfurl_links`
    robot.adapter.client.chat.postMessage(res.user.room, "This is a message!", {as_user: true, unfurl_links: false})

```