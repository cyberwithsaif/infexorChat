const admin = require('firebase-admin');
const { User } = require('../models');
const logger = require('../utils/logger');
let isInitialized = false;

try {
    // Requires the admin key to be placed at this exact path from the project root
    const serviceAccount = require('../../infexorchat-firebase-adminsdk.json');
    if (!admin.apps.length) {
        admin.initializeApp({
            credential: admin.credential.cert(serviceAccount)
        });
    }
    isInitialized = true;
    logger.info('Firebase Admin SDK initialized successfully');
} catch (error) {
    logger.error('Failed to initialize Firebase Admin SDK. Push notifications will be disabled.', error);
}

/**
 * Register / update device push token for a user
 */
exports.registerToken = async (userId, token) => {
    if (!token) return;
    await User.findByIdAndUpdate(userId, {
        fcmToken: token,
    });
};

/**
 * Remove push token (on logout)
 */
exports.removeToken = async (userId, token) => {
    await User.findByIdAndUpdate(userId, {
        fcmToken: '',
    });
};

/**
 * Send notification to a single user
 */
exports.sendToUser = async (userId, title, body, data = {}) => {
    if (!isInitialized) return;
    try {
        const user = await User.findById(userId).select('fcmToken');
        if (!user || !user.fcmToken) return;

        // Detect call payloads — send data-only FCM so Android doesn't
        // auto-show a system notification (our background handler creates
        // a custom full-screen intent notification for calls instead).
        const isCall = data.type === 'call' || data.type === 'video_call' || data.type === 'audio_call';

        const message = {
            data: {
                ...data,
                title: title || '',
                body: body || '',
                click_action: 'FLUTTER_NOTIFICATION_CLICK',
            },
            token: user.fcmToken,
            android: {
                priority: 'high',
            },
        };

        // Only add notification block for non-call messages
        if (!isCall) {
            message.notification = { title, body };
        }

        const response = await admin.messaging().send(message);
        logger.debug(`FCM sent to user ${userId} successfully: ${response}`);

    } catch (error) {
        logger.error(`Error sending FCM to user ${userId}:`, error);
        // Cleanup expired/invalid tokens
        if (error.code === 'messaging/invalid-registration-token' ||
            error.code === 'messaging/registration-token-not-registered') {
            await User.findByIdAndUpdate(userId, {
                fcmToken: ''
            });
        }
    }
};

/**
 * Send notification to all participants of a chat (except excludeUserId)
 */
exports.sendToChat = async (chatId, excludeUserId, title, body, data = {}) => {
    if (!isInitialized) return;
    try {
        const { Chat } = require('../models');
        const chat = await Chat.findById(chatId).select('participants');
        if (!chat) return;

        for (const participantId of chat.participants) {
            if (participantId.toString() !== excludeUserId.toString()) {
                await exports.sendToUser(participantId, title, body, data);
            }
        }
    } catch (error) {
        logger.error(`Error sending chat FCM for chat ${chatId}:`, error);
    }
};
