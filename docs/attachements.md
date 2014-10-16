It is possible to create more richly-formatted messages using Attachments.

![screenshot1](https://slack.global.ssl.fastly.net/13975/img/integrations/incoming_webhook_attachment.png)

In your scripts you could emit event called 'slack-attachment' as described below and pass additional fields according to your case.
![screenshot2](http://d.pr/i/uIqC+)

```coffeescript
# Description:
#   Demonstrating Slack Attachments.
#
# Commands:
#   hubot demo-attachment - Demo Attachement

module.exports = (robot) ->
  robot.respond /demo-attachment$/i, (msg) =>
    fields = []
    fields.push
      title: "Field 1: Title"
      value: "Field 1: Value"
      short: true

    fields.push
      title: "Field 2: Title"
      value: "Field 2: Value"
      short: true

    payload =
      message: msg.message
      content:
        text: "Attachement Demo Text"
        fallback: "Fallback Text"
        pretext: "This is Pretext"
        color: "#FF0000"
        fields: fields

    robot.emit 'slack-attachment', payload
```

You are able to pass multiple attachments by setting the `content` to an array of "attachment" objects.

```coffeescript
# ...

    payload =
      message: msg.message
      content: [
        text: "Attachement Demo Text"
        fallback: "Fallback Text"
        pretext: "This is Pretext"
        color: "#FF0000"
        fields: fields
      ,
        text: "Attachement Demo Text 2"
        fallback: "Fallback Text 2"
        pretext: "This is another attachment"
        color: "#00FF00"
        fields: fields
      ]

    robot.emit 'slack-attachment', payload
```
