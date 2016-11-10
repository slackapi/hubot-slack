MESSAGE_RESERVED_KEYWORDS = ['channel','group','everyone','here']


# https://api.slack.com/docs/formatting
class SlackFormatter

  constructor: (@dataStore) ->


  ###
  Formats links and ids
  ###
  links: (text) ->    
    regex = ///
      <              # opening angle bracket
      ([@#!])?       # link type
      ([^>|]+)       # link
      (?:\|          # start of |label (optional)
      ([^>]+)        # label
      )?             # end of label
      >              # closing angle bracket
    ///g

    text = text.replace regex, (m, type, link, label) =>
      switch type

        when '@'
          if label then return "@#{label}"
          user = @dataStore.getUserById link
          if user
            return "@#{user.name}"

        when '#'
          if label then return "\##{label}"
          channel = @dataStore.getChannelById link
          if channel
            return "\##{channel.name}"

        when '!'
          if link in MESSAGE_RESERVED_KEYWORDS
            return "@#{link}"
          else if label
            return label
          return m

        else
          link = link.replace /^mailto:/, ''
          if label and -1 == link.indexOf label
            "#{label} (#{link})"
          else
            link

    text = text.replace /&lt;/g, '<'
    text = text.replace /&gt;/g, '>'
    text = text.replace /&amp;/g, '&'


  ###
  Flattens message text and attachments into a multi-line string
  ###
  flatten: (message) ->
    text = []

    # basic text messages
    text.push(message.text) if message.text

    # append all attachments
    for attachment in message.attachments or []
      text.push(attachment.fallback)    

    # flatten array
    text.join('\n')


  ###
  Formats an incoming Slack message
  ###
  incoming: (message) ->
    @links @flatten message



module.exports = SlackFormatter
