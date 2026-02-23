const { User } = require('../models');
const logger = require('../utils/logger');

/**
 * Self-hosted notification service.
 * Uses Socket.IO for real-time delivery (already handled by socketHandler).
 * This service handles token cleanup and provides hooks for future
 * self-hosted push solutions (e.g. ntfy, Gotify, UnifiedPush).
 */

/**
 * Register / update device push token for a user
 * (Reserved for future self-hosted push gateway)
 */
exports.registerToken = async (userId, token) => {
    if (!token) return;
    await User.findByIdAndUpdate(userId, {
        $addToSet: { fcmTokens: token },
    });
};

/**
 * Remove push token (on logout)
 */
exports.removeToken = async (userId, token) => {
    if (!token) return;
    await User.findByIdAndUpdate(userId, {
        $pull: { fcmTokens: token },
    });
};

/**
 * Send notification to a user — currently a no-op since
 * Socket.IO handles real-time delivery in socketHandler.js.
 * Offline messages are delivered when the user reconnects.
 */
exports.sendToUser = async (userId, title, body, data = {}) => {
    // Socket.IO handles real-time delivery.
    // Messages are persisted in DB and delivered on reconnect.
    logger.debug(`Notification queued for user ${userId}: ${title}`);
};

/**
 * Send notification to all participants of a chat (except excludeUserId)
 */
exports.sendToChat = async (chatId, excludeUserId, title, body, data = {}) => {
    // Socket.IO handles real-time delivery.
    logger.debug(`Chat notification queued for chat ${chatId}`);
};
