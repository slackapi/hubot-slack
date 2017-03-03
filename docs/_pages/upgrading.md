---
layout: page
title: Upgrading from a Previous Version
permalink: /upgrading
order: 10
headings:
    - title: Upgrading from version 2 or earlier
    - title: Upgrading from version 3 or earlier
---

## Upgrading from version 3 or earlier

Version 4 of the {{ site.product_name }} adapter uses a more recent version of the
Slack Developer Kit for Node.js. As a result, there are some syntax changes within Hubot:

1. Before version 4, `msg.message.room` would return the name of the room
(e.g. `general`). `msg.message.room` now returns a room identifier
(e.g. `C03NM270D`). If you need to translate the room id to a room name,
you can look it up with the client:

    ```coffeescript
      robot.respond /what room am i in\?/i, (msg) ->
        room = msg.message.room
        roomName = robot.adapter.client.rtm.dataStore.getChannelById(room).name
        msg.send roomName
    ```

2. Version 3 of {{ site.product_name }} supported attachments by emitting a
`slack.attachment` event. In version 4, you use `msg.send`, passing an object
with an `attachments` array:

    ```coffeescript
      robot.respond /send attachments/i, (msg) ->
        msg.send(
          attachments: [
            {
              text: '*error*: something bad happened'
              fallback: 'error: something bad happened'
              color: 'danger'
              mrkdwn_in: ['text']
            }
          ]
        )
    ```

## Upgrading from version 2 or earlier

Version 3 of the {{ site.product_name }} requires different server support from
previous versions. If you have an existing "hubot" integration set up you'll
need to upgrade it:

- Go to https://my.slack.com/services/new/hubot and create a new hubot
  integration
- Run `npm install hubot-slack --save`
  to update your code.
- Test your bot locally using:
  `HUBOT_SLACK_TOKEN=xoxb-1234-5678-91011-00e4dd ./bin/hubot --adapter slack`
- Update your production startup scripts to pass the new `HUBOT_SLACK_TOKEN`.
  You can remove the other `HUBOT_SLACK_*` environment variables if you want.
- Deploy your new hubot to production.
- Once you're happy it works, disable the old hubot integration from
  https://my.slack.com/services

