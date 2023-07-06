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
        this.#webSocketClient.on('message', message => this.#onMessage(message))
        this.#webSocketClient.on('open', () => this.#open())
        this.#webSocketClient.on('close', () => this.#close())
        this.#webSocketClient.on('disconnect', () => this.#disconnect())
        this.#webSocketClient.on('error', error => this.#error(error))
    
    }
    async #mapToHubotMessage(message) {
        console.log(message)
        let user = this.robot.brain.users()[message.user]
        if(!user) {
            user = await this.#webClient.users.info({
                user: message.user
            })
            this.robot.brain.userForId(message.user, user)
        }

        return new TextMessage(new User(message.user, {
            room: message.channel
        }), message.text, message.ts)
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
    async #onMessage(message) {
        this.robot.logger.info(`Received a message from Slack: ${message.text}`)

        this.robot.receive(await this.#mapToHubotMessage(message?.event))
        message.ack().then(() => {
            this.robot.logger.debug('message acked')
        }).catch(this.robot.logger.error)
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
        this.#webClient.chat.postMessage(options.channel, message, options).then(result => {
            this.robot.logger.debug(`Successfully sent message to ${envelope.room}`)
        }).catch(e => this.robot.logger.error(e))
    }
    reply(envelope, ...strings) {
        this.robot.logger.info(`Replying to message in ${envelope.room}`)
        return this.send(envelope, ...strings)
    }
    run() {
        this.#webSocketClient.start().then(result => {
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
        return new SlackAdapter(robot, new SocketModeClient({ appToken: process.env.SLACK_APP_TOKEN }), new WebClient(process.env.SLACK_BOT_TOKEN, {
            logger: robot.logger,
            logLevel: process.env.HUBOT_SLACK_LOG_LEVEL || 'info'
        }), options)
    }
}