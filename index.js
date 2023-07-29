const SlackBot = require('./src/bot');
require('./src/extensions');

exports.use = function(robot) {
  let e;
  const options = {
    appToken: process.env.HUBOT_SLACK_APP_TOKEN,
    botToken: process.env.HUBOT_SLACK_BOT_TOKEN,
    disableUserSync: (process.env.DISABLE_USER_SYNC != null),
    apiPageSize: process.env.API_PAGE_SIZE,
    installedTeamOnly: (process.env.INSTALLED_TEAM_ONLY != null)
  };
  try {
    options.socketModeOptions = JSON.parse(process.env.HUBOT_SLACK_SOCKET_MODE_OPTS || '{}');
  } catch (error) {
    e = error;
    console.error(e);
  }
  return new SlackBot(robot, options);
};
