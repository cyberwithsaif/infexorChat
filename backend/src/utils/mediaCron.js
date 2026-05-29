const fs = require('fs');
const path = require('path');
const MediaCleanup = require('../models/MediaCleanup');
const logger = require('./logger');
const { uploadsDir } = require('../config/upload');

// Run every 1 hour (3600000 ms)
const CHECK_INTERVAL = 60 * 60 * 1000;

const startMediaCleanupCron = () => {
    logger.info('Media cleanup cron started');

    setInterval(async () => {
        try {
            const now = new Date();
            // Find all records where deleteAt is in the past
            const expiredMedia = await MediaCleanup.find({ deleteAt: { $lte: now } });

            if (expiredMedia.length > 0) {
                logger.info(`Found ${expiredMedia.length} expired media files to clean up.`);
            }

            for (const media of expiredMedia) {
                try {
                    // media.fileUrl is like "/uploads/images/file.jpg"
                    // We need to resolve it to absolute path
                    const relativePath = media.fileUrl.replace(/^\/uploads\//, '');
                    const absolutePath = path.join(uploadsDir, relativePath);

                    // Delete the original file
                    if (fs.existsSync(absolutePath)) {
                        fs.unlinkSync(absolutePath);
                        logger.info(`Deleted expired file: ${absolutePath}`);
                    }

                    // Also try to delete thumbnail if it's an image
                    const filename = path.basename(absolutePath);
                    const thumbPath = path.join(uploadsDir, 'thumbnails', `thumb_${filename}`);
                    if (fs.existsSync(thumbPath)) {
                        fs.unlinkSync(thumbPath);
                        logger.info(`Deleted expired thumbnail: ${thumbPath}`);
                    }

                    // Delete the DB record
                    await MediaCleanup.findByIdAndDelete(media._id);
                } catch (err) {
                    logger.error(`Error deleting media ${media.fileUrl}: ${err.message}`);
                }
            }
        } catch (error) {
            logger.error('Error in media cleanup cron:', error);
        }
    }, CHECK_INTERVAL);
};

// Sweep expired (disappearing) messages every minute and tell clients to
// silently remove them. Separate, faster loop than the hourly media cleanup.
const startDisappearingMessagesCron = () => {
    logger.info('Disappearing-messages cron started');
    const Message = require('../models/Message');
    const Chat = require('../models/Chat');

    setInterval(async () => {
        try {
            const now = new Date();
            const expired = await Message.find({
                expiresAt: { $ne: null, $lte: now },
            }).select('_id chatId').lean();
            if (expired.length === 0) return;

            // Notify participants so the bubbles vanish live (best-effort).
            let io = null;
            try { io = require('../config/socket').getIO(); } catch { /* not ready */ }
            if (io) {
                const byChat = {};
                for (const m of expired) {
                    const cid = m.chatId.toString();
                    (byChat[cid] = byChat[cid] || []).push(m._id.toString());
                }
                for (const [cid, ids] of Object.entries(byChat)) {
                    const chat = await Chat.findById(cid).select('participants').lean();
                    if (!chat) continue;
                    ids.forEach((messageId) => {
                        chat.participants.forEach((pid) => {
                            io.to(`user:${pid}`).emit('message:expired', { chatId: cid, messageId });
                        });
                    });
                }
            }

            const ids = expired.map((m) => m._id);
            await Message.deleteMany({ _id: { $in: ids } });
            logger.info(`Disappearing-messages: removed ${ids.length} expired message(s)`);
        } catch (error) {
            logger.error('Error in disappearing-messages cron:', error);
        }
    }, 60 * 1000);
};

module.exports = { startMediaCleanupCron, startDisappearingMessagesCron };
