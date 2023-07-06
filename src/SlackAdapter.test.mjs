import { describe, it, beforeEach, afterEach } from 'node:test'
import assert from 'node:assert/strict'
import { SlackAdapter } from './SlackAdapter.mjs'
import Robot from 'hubot/src/robot.js'
import { TextMessage } from 'hubot/src/message.js'
import User from 'hubot/src/user.js'
import EventEmitter from 'node:events'

class SlackClientMock extends EventEmitter {
    #useRtmConnect = false
    #delegate = null
    constructor(token, useRtmConnect, delegate) {
        super()
        this.token = token
        this.#useRtmConnect = useRtmConnect
        this.#delegate = delegate
    }
    async start() {
        if(this.#delegate?.start) {
            return await this.#delegate.start(this)
        }
        this.emit('authenticated', new Error('Not authenticated'))
    }
}
const buildATestUser = () => ({
  ok: true,
  user: {
    id: 'U3FRN2E9Y',
    team_id: 'T040CSN34',
    name: 'bossdog',
    deleted: false,
    color: 'e96699',
    real_name: 'Joey Guerra',
    tz: 'America/Chicago',
    tz_label: 'Central Daylight Time',
    tz_offset: -18000,
    profile: {
      title: 'type',
      phone: '214-682-8565',
      skype: '',
      real_name: 'Joey Guerra',
      real_name_normalized: 'Joey Guerra',
      display_name: 'joey',
      display_name_normalized: 'joey',
      fields: null,
      status_text: '',
      status_emoji: '',
      status_emoji_display_info: [],
      status_expiration: 0,
      avatar_hash: 'a350644dd441',
      image_original: 'https://avatars.slack-edge.com/2018-08-02/408988542176_a350644dd4414bddea09_original.jpg',
      is_custom_image: true,
      first_name: 'Joey',
      last_name: 'Guerra',
      image_24: 'https://avatars.slack-edge.com/2018-08-02/408988542176_a350644dd4414bddea09_24.jpg',
      image_32: 'https://avatars.slack-edge.com/2018-08-02/408988542176_a350644dd4414bddea09_32.jpg',
      image_48: 'https://avatars.slack-edge.com/2018-08-02/408988542176_a350644dd4414bddea09_48.jpg',
      image_72: 'https://avatars.slack-edge.com/2018-08-02/408988542176_a350644dd4414bddea09_72.jpg',
      image_192: 'https://avatars.slack-edge.com/2018-08-02/408988542176_a350644dd4414bddea09_192.jpg',
      image_512: 'https://avatars.slack-edge.com/2018-08-02/408988542176_a350644dd4414bddea09_512.jpg',
      image_1024: 'https://avatars.slack-edge.com/2018-08-02/408988542176_a350644dd4414bddea09_1024.jpg',
      status_text_canonical: '',
      team: 'T040CSN34'
    },
    is_admin: true,
    is_owner: false,
    is_primary_owner: false,
    is_restricted: false,
    is_ultra_restricted: false,
    is_bot: false,
    is_app_user: false,
    updated: 1629316975,
    is_email_confirmed: true,
    who_can_share_contact_card: 'EVERYONE'
  },
  response_metadata: {
    scopes: [
      'app_mentions:read',    'channels:history',
      'channels:join',        'channels:read',
      'channels:write.topic', 'chat:write',
      'commands',             'files:read',
      'files:write',          'groups:history',
      'users:write',          'links:read',
      'im:history',           'im:read',
      'reactions:read',       'reactions:write',
      'groups:read',          'mpim:read',
      'emoji:read',           'users:read'
    ],
    acceptedScopes: [ 'users:read' ]
  }
})

const buildSlackMessage = event => ({
    ack: () => {},
    envelope_id: 'e9b92395-bedd-4da7-a1b2-9bd1c28a423d',
    body: {
        token: 'lsO9JwCmB7NuNgWg3tKEdY6K',
        team_id: 'T040CSN34',
        context_team_id: 'T040CSN34',
        context_enterprise_id: null,
        api_app_id: 'A05CZQ3NCP4',
        event: {
            client_msg_id: event?.messageId ?? 'be201e20-d035-44dc-a0e2-befc2b5bd13d',
            type: event?.type ?? 'message',
            text: event?.text ?? '<@U05CZLS39QT> help',
            user: event?.user ?? 'U3FRN2E9Y',
            ts: event?.ts ?? '1688420854.574989',
            blocks: event?.blocks ?? [],
            team: event?.team ?? 'T040CSN34',
            channel: event?.channel ?? 'CDUEY6A1W',
            event_ts: event?.ts ?? '1688420854.574989',
            channel_type: event.channel_type ?? 'channel'
        },
        type: 'event_callback',
        event_id: 'Ev05F9TNCNDB',
        event_time: 1688420854,
        authorizations: [ [Object] ],
        is_ext_shared_channel: false,
        event_context: '4-eyJldCI6Im1lc3NhZ2UiLCJ0aWQiOiJUMDQwQ1NOMzQiLCJhaWQiOiJBMDVDWlEzTkNQNCIsImNpZCI6IkNEVUVZNkExVyJ9'
    },
    event: {
        client_msg_id: event?.messageId ?? 'be201e20-d035-44dc-a0e2-befc2b5bd13d',
        type: event?.type ?? 'message',
        text: event?.text ?? '<@U05CZLS39QT> help',
        user: event?.user ?? 'U3FRN2E9Y',
        ts: event?.ts ?? '1688420854.574989',
        blocks: event?.blocks ?? [],
        team: event?.team ?? 'T040CSN34',
        channel: event?.channel ?? 'CDUEY6A1W',
        event_ts: event?.ts ?? '1688420854.574989',
        channel_type: event.channel_type ?? 'channel'
    },
    retry_num: 0,
    retry_reason: '',
    accepts_response_payload: false
})

const authenticatedPerson = obj => ({
    installed_team_id: 'T12345678',
    team: {
        id: 'T12345678',
        name: 'Team Name'
    },
    self: {
        id: 'U12345678',
        token: 'fake-token',

    }
})

const token = 'some-fake-token'
const makeRobot = (delegate, webClientMock) => {
    const robot = new Robot('Slack', false, 'hubot')
    robot.adapter = new SlackAdapter(robot, new SlackClientMock(token, true, delegate), webClientMock ?? {
        chat: {
            async postMessage(channel, message, options) {}
        }
    }, { token })
    return robot
}
const mapToHubotMessage = (message) => {
    return new TextMessage(new User(message.user, {
        room: message.channel
    }), message.text, message.ts)
}

describe('Adapter', async () => {
    let robot = null
    beforeEach(async () => {
        robot = makeRobot()
    })
    it('should emit "connected" after calling run', (t, done) => {
        robot.adapter.on('connected', () => {
            robot.shutdown()
            assert.ok(true)
            done()
        })
        robot.run()
    })
})

describe('Authenticate', async () => {
    let robot = null
    beforeEach(async () => {
        robot = makeRobot({
            async start(adapter) {
                adapter.emit('authenticated', new Error('Not authenticated'))
            }
        })
    })
    it('should not be authenticated', (t, done) => {
        robot.adapter.on('authenticated', (err, identiy) => {
            robot.shutdown()
            assert.ok(err)
            assert.deepEqual(err.message, 'Not authenticated')
            done()
        })
        robot.run()
    })
})

describe('Listen to messages', async () => {
    let robot = null
    beforeEach(async () => {
        robot = makeRobot({
            async start(adapter) {
                adapter.emit('authenticated', authenticatedPerson(), null)
            }
        })
        robot.run()
    })
    afterEach(async () => {
        robot.shutdown()
    })
    it('should listen to a message', (t, done) => {
        robot.listen(message => {
            if(message instanceof TextMessage) {
                assert.deepEqual(message.text, 'Hello world')
                done()
                return true
            }
            assert.fail('expect a message')
        },
        {id: 'message listener'},
        res => {
            res.send('hi')
            assert.ok(true, 'should be called for message')
        })
        robot.receive(mapToHubotMessage(buildSlackMessage({
            "type": "message",
            "channel": "C123ABC456",
            "user": "U123ABC456",
            "text": "Hello world",
            "ts": "1355517523.000005"
        }).event))
    })
    it('should hear a message, which uses regex for matching', (t, done) => {
        robot.hear(/hello/i, {id: 'message listener'},
            context => {
                assert.deepEqual(context.message.text, '@hubot hello')
                done()
                return true
            })

        robot.receive(mapToHubotMessage(buildSlackMessage({
            "type": "message",
            "channel": "C123ABC456",
            "user": "U123ABC456",
            "text": "<@U05CZLS39QT> hello",
            "ts": "1355517523.000005"
        }).event))
    })
})

describe('Send messages back', async () => {
    it('should reply to a message that was sent to Hubot', (t, done) => {
        const robot = makeRobot({
            async start(adapter) {
                adapter.emit('authenticated', authenticatedPerson(), null)
            }
        }, {
            chat: {
                async postMessage(channel, message, options) {
                    assert.deepEqual(channel, 'C123ABC456')
                    assert.deepEqual(message, 'hi')
                    robot.shutdown()
                    done()
                }
            },
            users: {
                info(params) {
                    return buildATestUser()
                }
            }
        })
        robot.run()
        robot.respond(/hello/i, {id: 'message responder'},
            context => {
                assert.deepEqual(context.message.text, '@hubot hello')
                context.reply('hi')
            })
        robot.adapter.on('connected', () => {
            robot.receive(mapToHubotMessage(buildSlackMessage({
                "type": "message",
                "channel": "C123ABC456",
                "user": "U123ABC456",
                "text": "<@U05CZLS39QT> hello",
                "ts": "1355517523.000005"
            }).event))
        })
    })
    
})
