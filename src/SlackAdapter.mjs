import Adapter from 'hubot/src/adapter.js'
import { TextMessage } from 'hubot/src/message.js'
import User from 'hubot/src/user.js'
import { SocketModeClient } from '@slack/socket-mode'
import { WebClient } from '@slack/web-api'

export class SlackIdentity {
    constructor(obj) {
        this.installed_team_id = obj.installed_team_id
        this.team_id = obj.team_id
        this.team_name = obj.team_name
        this.user_id = obj.user_id
        this.user_token = obj.user_token
        this.bot_token = obj.bot_token
        this.bot_user_id = obj.bot_user_id
        this.bot_id = obj.bot_id
    }
}

export class ResponseMetadata {
    constructor(obj) {
        this.scopes = obj?.scopes
        this.acceptedScopes = obj?.acceptedScopes
    }
}
export class AuthenticationResponse {
    constructor(obj) {
        this.ok = obj?.ok
        this.url = obj?.url
        this.error = obj?.error
        this.responseMetadata = new ResponseMetadata(obj?.responseMetadata)
    }
}
export class AuthTestResponse {
    constructor(obj) {
        this.ok = obj?.ok
        this.url = obj?.url
        this.error = obj?.error
        this.user = new User(obj?.user_id, {
            name: obj?.user,
            teamId: obj?.team_id,
            team: obj?.team,
        })
        this.responseMetadata = new ResponseMetadata(obj?.response_metadata)
        this.team = obj?.team
        this.userId = obj?.user_id
        this.botId = obj?.bot_id
        this.isEnterpriseInstall = obj?.is_enterprise_install
    }
}
export class SlackBotProfile {
    constructor(obj) {
        this.id = obj?.id
        this.deleted = obj?.deleted
        this.name = obj?.name
        this.updated = obj?.updated
        this.appId = obj?.app_id
        this.icons = obj?.icons
        this.teamId = obj?.team_id
    }
}
export class SlackMessage {
    constructor(obj) {
        this.botId = obj?.bot_id
        this.type = obj?.type
        this.text = obj?.text
        this.user = obj?.user
        this.appId = obj?.app_id
        this.blocks = obj?.blocks
        this.team = obj?.team
        this.botProfile = obj?.bot_profile
        this.attachments = obj?.attachments
        this.ts = obj?.ts
    }
}
export class SlackMessageEvent {
    constructor(obj) {
        this.clientMsgId = obj?.client_msg_id
        this.type = obj?.type
        this.subType = obj?.subtype
        this.message = obj?.message ? new SlackMessage(obj.message) : null
        this.previousMessage = obj?.previous_message ? new SlackMessage(obj.previous_message) : null
        this.text = obj?.text
        this.user = obj?.user
        this.botId = obj?.bot_id
        this.blocks = obj?.blocks
        this.team = obj?.team
        this.channel = obj?.channel
        this.hidden = obj?.hidden
        this.ts = obj?.ts
        this.eventTs = obj?.event_ts
        this.channelType = obj?.channel_type
    }
}
export class SlackMessageBody {
    constructor(obj) {
        this.token = obj?.token
        this.teamId = obj?.team_id
        this.contextTeamId = obj?.context_team_id
        this.contextEnterpriseId = obj?.context_enterprise_id
        this.apiAppId = obj?.api_app_id
        this.event = new SlackMessageEvent(obj?.event)
        this.type = obj?.type
        this.eventId = obj?.event_id
        this.eventTime = obj?.event_time
        this.authorizations = obj?.authorizations
        this.isExtSharedChannel = obj?.is_ext_shared_channel
        this.eventContext = obj?.event_context
    }
}
export class SlackChannel {
    constructor(obj) {
        this.id = obj?.id
        this.name = obj?.name
        this.isChannel = obj?.is_channel
        this.isGroup = obj?.is_group
        this.isIm = obj?.is_im
        this.isMpIm = obj?.is_mpim
        this.isPrivate = obj?.is_private
        this.created = obj?.created
        this.isArchived = obj?.is_archived
        this.isGeneral = obj?.is_general
        this.isOrgShared = obj?.is_org_shared
        this.isShared = obj?.is_shared
        this.isPendingExtShared = obj?.is_pending_ext_shared
        this.pendingShared = obj?.pending_shared
        this.contextTeamId = obj?.context_team_id
        this.updated = obj?.updated
        this.unlinked = obj?.unlinked
        this.nameNormalized = obj?.name_normalized
        this.user = obj?.user
        this.lastRead = obj?.last_read
        this.latest = obj?.latest
        this.parentConversation = obj?.parent_conversation
        this.creator = obj?.creator
        this.isExtShared = obj?.is_ext_shared
        this.sharedTeamIds = obj?.shared_team_ids
        this.pendingConnectedTeamIds = obj?.pending_connected_team_ids
        this.isMember = obj?.is_member
        this.topic = obj?.topic
        this.purpose = obj?.purpose
        this.previousNames = obj?.previous_names
    }
}
export class SlackResponse {
    constructor(obj) {
        this.ack = obj?.ack
        this.envelopeId = obj?.envelope_id
        this.body = new SlackMessageBody(obj?.body)
        this.retryNum = obj?.retry_num
        this.retryReason = obj?.retry_reason
        this.acceptsResponsePayload = obj?.accepts_response_payload
    }
}

class SlackAdapter extends Adapter {
    #webSocketClient = null
    #webClient = null
    #options = null
    #errors = []
    constructor(robot, webSocketClient, webClient, options) {
        super(robot)
        this.name = 'Slack Adapter'
        this.#options = options
        this.#webSocketClient = webSocketClient
        this.#webClient = webClient
        this.#webSocketClient.on('authenticated', rtmStartData => this.#onAuthenticated(rtmStartData))
        this.#webSocketClient.on('message', async message => await this.#onMessage(message))
        this.#webSocketClient.on('open', () => this.#open())
        this.#webSocketClient.on('close', () => this.#close())
        this.#webSocketClient.on('disconnect', () => this.#disconnect())
        this.#webSocketClient.on('error', error => this.#error(error))
    
    }
    async mapToHubotMessage(event) {
        // console.error(event)
        const fromBrain = this.robot.brain.users()[event.user]
        if(!fromBrain) {
            const response = await this.#webClient.users.info({
                user: event.user
            })
            this.robot.brain.userForId(event.user, response.user)
        }
        const fromUser = this.robot.brain.users()[event.user]
        return new TextMessage(new User(event.user, {
            room: event.channel,
            name: fromUser.name
        }), event.text, event.ts)
    }
    #error(error) {
        this.#errors.push(error)
        this.emit('error', error)
    }
    #disconnect() {
        this.emit('disconnected')
    }
    #close() {
        this.#webClient.disconnect()
    }
    #open() {
        this.robot.logger.info('Connected to Slack after open event')
        return this.emit('connected');
    }
    replaceBotIdWithName(event) {
        const botId = this.robot.self.id
        const botName = this.robot.self.name
        const text = event.text ?? event.message?.text
        if(text.includes(`<@${botId}>`)) {
            return text.replace(`<@${botId}>`, `@${botName}`)
        }
        return text
    }
    async #onMessage(message) {
        const slackMessage = new SlackResponse(message)
        if(slackMessage.body.event.botId && slackMessage.body.event.user === this.robot.self.id) {
            this.robot.logger.info('Ignoring message from self')
            return await message.ack()
        }
        // add the bot id to the message if it's a direct message
        if(slackMessage.body.event.text
            && slackMessage.body.event.channelType == 'im'
            && !slackMessage.body.event?.text?.includes(this.robot.self.id)) {
            slackMessage.body.event.text = `<@${this.robot.self.id}> ${slackMessage.body.event.text}`
        }
        this.robot.logger.info(`Received a message from Slack:`, slackMessage)
        slackMessage.body.event.text = this.replaceBotIdWithName(slackMessage.body.event)
        if(slackMessage.body.event.message) {
            slackMessage.body.event.message.text = this.replaceBotIdWithName(slackMessage.body.event)
        }
        try {
            const textMessage = await this.mapToHubotMessage(slackMessage.body.event)
            this.robot.receive(textMessage)
        } catch(error) {
            this.robot.error(error)
        }
        await message.ack()
    }
    #onAuthenticated(rtmStartData) {
        if(rtmStartData instanceof Error) {
            this.#errors.push(rtmStartData)
            this.emit('authenticated', rtmStartData, null)
            return
        }
        this.emit('authenticated', null, new AuthenticationResponse(rtmStartData))
    }
    send(envelope, ...strings) {
        const options = {
            as_user: true,
            link_names: 1,
            unfurl_links: false,
            unfurl_media: false
        }
        const message = strings.join(' ')
        if(envelope.room[0] === 'D') {
            options.channel = envelope.user.id
        } else {
            options.channel = envelope.room
        }
        this.#webClient.chat.postMessage({ channel: options.channel, text: message }).then(result => {
            this.robot.logger.debug(`Successfully sent message to ${envelope.room}`)
        }).catch(e => this.robot.logger.error(e))
    }
    reply(envelope, ...strings) {
        this.robot.logger.info(`Replying to message in ${envelope.room}`)
        return this.send(envelope, ...strings)
    }
    run() {
        this.#webSocketClient.start().then(async result => {
            // const channelResponse = await this.#webClient.conversations.list()
            // console.log('channelResponse', channelResponse)
            const response = await this.#webClient.auth.test()
            this.robot.self = new AuthTestResponse(response).user
            this.robot.logger.info('Connected to Slack after starting socket client.')
            this.emit('connected')
        }).catch(e => this.robot.logger.error(e))
    }
}

export {
    SlackAdapter
}

export default {
    use(robot) {
        const options = {
            token: process.env.SLACK_APP_TOKEN,
            disableUserSync: (process.env.DISABLE_USER_SYNC != null),
            apiPageSize: process.env.API_PAGE_SIZE,
            installedTeamOnly: (process.env.INSTALLED_TEAM_ONLY != null),
            rtm: JSON.parse(process.env.HUBOT_SLACK_RTM_CLIENT_OPTS || '{}'),
            rmStart: JSON.parse(process.env.HUBOT_SLACK_RTM_START_OPTS || '{}'),
        }
        options.rtm.useRtmConnect = true
        return new SlackAdapter(robot, new SocketModeClient({ appToken: process.env.HUBOT_SLACK_APP_TOKEN }), new WebClient(process.env.HUBOT_SLACK_BOT_TOKEN, {
            logger: robot.logger,
            logLevel: process.env.HUBOT_SLACK_LOG_LEVEL || 'info'
        }), options)
    }
}