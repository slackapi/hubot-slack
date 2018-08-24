---
layout: page
title: Basic Usage
permalink: /basic_usage
order: 4
headings:
    - title: Listening for a message
    - title: Messages directed to your Hubot
    - title: Sending a response
    - title: User and conversation mentions
    - title: Using the Slack Web API
    - title: Working with threads
    - title: Message reactions
    - title: Presence changes
    - title: Send a message to a different channel
    - title: Text formatting and raw messages
---

Most Hubots are designed to react to user input – a user makes a request, and Hubot responds, often after going out
into the world to trigger some action (building your code, deploying to production, and so on). Many of the tasks
you'd like to accomplish are already well documented in the [official Hubot documentation](https://hubot.github.com/docs/).
Nevertheless, we'll cover the basics, as well as some interesting Slack-specific use cases.

--------

## Listening for a message

You can listen for messages in any channel that your Hubot has been invited into very simply, by using `robot.hear` with
a RegExp to match against. Any message that matches the RegExp will trigger the function.

```coffeescript
module.exports = (robot) ->

  # Any message that contains "badger" will trigger the following function
  robot.hear /badger/i, (res) ->

    # res.message is a SlackTextMessage instance that represents the incoming message Hubot just heard
    robot.logger.debug "Received message #{res.message.text}"
```

Hubot will only hear messages in converastions where it is a member. A human must invite Hubot into conversations
(shortcut: `/invite @username`).

--------

## Messages directed to your Hubot

If you want to specifically listen for messages that mention your Hubot, use the `robot.respond` method. You can also
be more specific using a RegExp (or don't be more specific, `/.*/` will match all messages).

```coffeescript
module.exports = (robot) ->

  # Any message that contains "badger" and is directed at Hubot (in a DM or starting with its name)
  # will trigger the following function
  robot.respond /badger/i, (res) ->
    robot.logger.debug "Received message #{res.message.text}"
```

--------

## Sending a response

Responding to a message is straightforward, regardless of whether the message was sent to your Hubot specifically or to
anyone in general.

```coffeescript
module.exports = (robot) ->

  robot.hear /badger/i, (res) ->
    # Hubot sends a response to the same channel it heard the incoming message
    res.send "Yes, more badgers please!"
```

--------

## User and conversation mentions

When your Hubot hears a message, it might contain mentions of other users, channels, or groups. The `text` property is
pretty and human-readable. But this isn't great for scripting because
[usernames are deprecated](https://api.slack.com/changelog/2017-09-the-one-about-usernames), and display names and
conversation names can change. What you really want is an ID; it's stable to store and gives your Hubot an easy way to
write mentions that have the user's preferred display name.

Each incoming message has a `mentions` array that contains the ID and any other information known about the user or
conversation that was mentioned.

```coffeescript
module.exports = (robot) ->
  # A map of user IDs to scores
  thank_scores = {}

  robot.hear /thanks/i, (res) ->
    # filter mentions to just user mentions
    user_mentions = (mention for mention in res.message.mentions when mention.type is "user")

    # when there are user mentions...
    if user_mentions.length > 0
      response_text = ""

      # process each mention
      for { id } in user_mentions
        # increment the thank score
        thank_scores[id] = if thank_scores[id]? then (thank_scores[id] + 1) else 1
        # show the total score in the message with a properly formatted mention (uses display name)
        response_text += "<@#{id}> has been thanked #{thank_scores[id]} times!\n"

      # send the response
      res.send response_text
```

--------

## Using the Slack Web API

You can access the [Slack Web API](https://api.slack.com/web_api) from your Hubot. Start by installing the
[Slack Developer Kit for Node.js](https://slackapi.github.io/node-slack-sdk/) package into your Hubot project:

```
npm install --save @slack/client
```

Next, modify your script to instatiate a `WebClient` object using the same token your Hubot used to connect.

```coffeescript
# Import the Slack Developer Kit
{WebClient} = require "@slack/client"

module.exports = (robot) ->
  web = new WebClient robot.adapter.options.token

  # remainder of your script...
```

Finally, anytime you'd like to call a Web API method, call it like a method on `web`.

```coffeescript
# Import the Slack Developer Kit
{WebClient} = require "@slack/client"

module.exports = (robot) ->
  web = new WebClient robot.adapter.options.token

  robot.hear /test/i, (res) ->
    web.api.test()
      .then () -> res.send "Your connection to the Slack API is working!"
      .catch (error) -> res.send "Your connection to the Slack API failed :("
```

You only have access to the Web API methods that your bot token is authorized to use. Depending on
[how you installed Hubot]({{ site.baseurl }}{% link index.md %}#{{ "Getting a Slack token" | slugify }}), the
exact list of methods is either those checked for Custom Bots or App Bots in the
[bot methods table](https://api.slack.com/bot-users#bot_methods). If you have an App Bot and need to access a method
only available to a Custom Bot, now might be the right time to switch. If you need access to a method that isn't listed
in the table at all, see
[Accessing more API methods and distribution]({{ site.baseurl }}{% link _pages/advanced_usage.md %}#{{ "Accessing more API methods and distribution" | slugify }}).

--------

## Working with threads

Slack has the concept of [threaded messages](https://api.slack.com/docs/message-threading), which Hubot wasn't
directly designed to support. However, with a little bit of knowledge about the underlying messages, you can create
new threads and send messages into a thread using Hubot.


```coffeescript
module.exports = (robot) ->

  robot.hear /badger/i, (res) ->
    if res.message.thread_ts?
      # The incoming message was inside a thread, responding normally will continue the thread
      res.send "Did someone say BADGER?"
    else
      # The incoming message was not inside a thread, so lets respond by creating a new thread
      res.message.thread_ts = res.message.rawMessage.ts
      res.send "Slight digression, we need to talk about these BADGERS"
```

If you want to use the `reply_broadcast` feature of threads, you'll have to
[use the Web API directly](#{{"Using the Slack Web API" | slugify}}) for the `chat.postMessage` method.

--------

## Message reactions

Of course, Slack is more than just text messages. Users can send
[emoji reactions](https://get.slack.help/hc/en-us/articles/206870317-Emoji-reactions) to messages as well. Your Hubot
can both listen for these from other users, and send reactions of its own. Here is a recipe to listen for
emoji reactions and add the same reaction back to the same message.

```coffeescript
{WebClient} = require "@slack/client"

module.exports = (robot) ->
  web = new WebClient robot.adapter.options.token

  robot.react (res) ->

    # res.message is a ReactionMessage instance that represents the reaction Hubot just heard
    if res.message.type == "added" and res.message.item.type == "message"

      # res.messsage.reaction is the emoji alias for the reaction Hubot just heard
      web.reactions.add
        name: res.message.reaction,
        channel: res.message.item.channel,
        timestamp: res.message.item.ts
```

When using `robot.react` as shown above, the `res.message` value is of type `ReactionMessage`. In addition to the normal
message properties, this type has a few really helpful properties you might want to use in your script:

*  `type`: This is either `"added"` or `"removed"`, depending on whether, you guessed it, the reaction was added or
   removed.
*  `reaction`: The name of the emoji reaction. For example, when adding a 👍 reaction, this value is
   `"thumbsup"`.
*  `item`: This is either the message, the file, or the comment where this reaction took place.
*  `item_user`: The user who created the item. This value can be `undefined` if the item was created by a custom
   integration (not a Slack App).
*  `event_ts`: The timestamp of when this reaction message took place.

--------

## Presence changes

Each time a user changes from away to active, or vice-versa, Hubot can listen that event.

```coffeescript
module.exports = (robot) ->

  robot.presenceChange (res) ->

    # res.message is a PresenceMessage instance that represents the presence change Hubot just heard
    names = (user.name for user in res.message.users).join ", "

    message = if res.message.presence is "away" then "Bye bye #{names}" else "Glad you are back #{names}"
    robot.logger.debug message
```

--------

## Send a message to a different channel

Responding right back to an incoming message is great, but sometimes you want send a message to a different channel.
Hubot calls channels "rooms" and this adapter identifies rooms by channel ID, **not by channel name**. If your Hubot
wants to send a message into another channel, it first needs to find that channel ID. You might get a channel ID from
a previous message or you might use the Web API to translate a channel name to a channel ID. In the following example,
we use the Web API to translate to default named channel to an ID and then store it in a variable. There's a listener
set up that can update that variable based on an incoming message. Then a new listener is used to send data into
the current channel in the variable, no matter where the incoming message is received.

```coffeescript
{WebClient} = require "@slack/client"

module.exports = (robot) ->
  web = new WebClient robot.adapter.options.token

  # When the script starts up, there is no notification room
  notification_room = undefined

  # Immediately, a request is made to the Slack Web API to translate a default channel name into an ID
  default_channel_name = "general"
  web.channels.list()
    .then (api_response) ->
      # List is searched for the channel with the right name, and the notification_room is updated
      room = api_response.channels.find (channel) -> channel.name is default_channel_name
      notification_room = room.id if room?

    # NOTE: for workspaces with a large number of channels, this result in a timeout error. Use pagination.
    .catch (error) -> robot.logger.error error.message

  # Any message that says "send updates here" will change the notification room
  robot.hear /send updates here/i, (res) ->
    notification_room = res.message.rawMessage.channel.id

  # Any message that says "my update" will cause Hubot to echo that message to the notification room
  robot.hear /my update/i, (res) ->
    if notification_room?
      robot.messageRoom(notification_room, "An update from: <@#{res.message.user.id}>: '#{res.message.text}'")
```

--------

## Text formatting and raw messages

When your Hubot receives a message, the adapter does its best to make the `text` easy to work with by formatting links
and mentions. This formatting sometimes removes meaningful information from the text. If you want to access the
unaltered text in the incoming message, you can use the `rawText` property. Similarly, if you need to access any other
property of the incoming Slack message, use the `rawMessage` property.

```coffeescript
module.exports = (robot) ->

  # listen to all incoming messages
  robot.hear /.*/, (res) ->
    # find URLs in the rawText
    urls = res.message.rawText.match /https?:\/\/[^\|>\s]+/gi

    # log each link found
    robot.logger.debug ("link shared: #{url}" for url in urls).join("\n") if urls
```
