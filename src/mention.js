/*
 * decaffeinate suggestions:
 * DS206: Consider reworking classes to avoid initClass
 * DS207: Consider shorter variations of null checks
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/main/docs/suggestions.md
 */
class SlackMention {
	static initClass() {
	
		module.exports = SlackMention;
	}

	/**
	 * SlackMention is an instance of a mention within a SlackTextMessage.
	 * @constructor
	 * @param {string} id   - The user or conversation id that the mention references
	 * @param {string} type - The type of mention ('user' or 'conversation')
	 * @param {Object} info - An object with additional info about the message reference, not guaranteed
	 */
	constructor(id, type, info) {
		this.id = id;
		this.type = type;
		this.info = (info != null) ? info : undefined;
	}
}
SlackMention.initClass();
