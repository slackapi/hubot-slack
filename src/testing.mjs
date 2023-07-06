import { SocketModeClient, LogLevel } from '@slack/socket-mode'
import { WebClient } from '@slack/web-api'
const logLevel = LogLevel.DEBUG
const socketModeClient = new SocketModeClient({
  appToken: process.env.SLACK_APP_TOKEN,
  logLevel,
  // pingPongLoggingEnabled: true,
  // serverPingTimeout: 30000,
  // clientPingTimeout: 5000,
})
const webClient = new WebClient(process.env.SLACK_BOT_TOKEN, {
  logLevel,
})
const receive = async message => {
    const { body, ack } = message
    console.log('receiveing event', message)
    try {
        await ack()
    } catch (e) {
        console.error(e)
    }
}
socketModeClient.on('message', receive)
await socketModeClient.start()
