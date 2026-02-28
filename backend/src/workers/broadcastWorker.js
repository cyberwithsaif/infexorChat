const { Worker } = require('bullmq');
const mongoose = require('mongoose');
const logger = require('../utils/logger');
const { connection } = require('../config/queue');
const { Broadcast, Device } = require('../models');
const audienceService = require('../services/audienceService');
const notificationService = require('../services/notificationService');
const apnsService = require('../services/apnsService');
const admin = require('firebase-admin');

// 1. BullMQ Worker Definition
const broadcastWorker = new Worker(
    'broadcast-queue',
    async (job) => {
        const { broadcastId } = job.data;
        logger.info(`[BroadcastWorker] Starting job ${job.id} for broadcast: ${broadcastId}`);

        const broadcast = await Broadcast.findById(broadcastId);
        if (!broadcast) {
            throw new Error(`Broadcast ${broadcastId} not found`);
        }

        if (broadcast.status !== 'queued') {
            logger.warn(`[BroadcastWorker] Broadcast ${broadcastId} already processed or cancelled. Status: ${broadcast.status}`);
            return;
        }

        // Mark as sending
        broadcast.status = 'sending';
        await broadcast.save();

        let successCount = 0;
        let failureCount = 0;
        let invalidTokens = [];

        try {
            // 2. Stream tokens memory-safely from the DB
            const cursor = audienceService.getTokenStream(broadcast.segment, broadcast.platform);

            let batchFCM = [];
            let batchAPNS = [];

            for await (const device of cursor) {
                // Enforce specific segment logic that requires User table rules mapped (e.g. banned)
                if (broadcast.segment === 'banned' && device.userId?.status !== 'banned') continue;
                if (broadcast.segment !== 'banned' && device.userId?.status === 'banned') continue;

                if (device.platform === 'android') {
                    batchFCM.push(device.fcmToken);
                } else if (device.platform === 'ios') {
                    batchAPNS.push(device.fcmToken);
                }

                // Process FCM batch of exactly 500 (Firebase Admin SDK limit is 500 per sendMulticast)
                if (batchFCM.length >= 500) {
                    const result = await processFCMBatch(batchFCM, broadcast.title, broadcast.message, broadcast.link);
                    successCount += result.success;
                    failureCount += result.failure;
                    invalidTokens.push(...result.invalidTokens);
                    batchFCM = [];

                    await updateProgress(broadcastId, successCount, failureCount);
                    await delay(100); // 100ms yield to not block event loop
                }

                // Process APNs batch
                if (batchAPNS.length >= 500) {
                    const result = await processAPNSBatch(batchAPNS, broadcast.title, broadcast.message, broadcast.link);
                    successCount += result.success;
                    failureCount += result.failure;
                    invalidTokens.push(...result.invalidTokens);
                    batchAPNS = [];

                    await updateProgress(broadcastId, successCount, failureCount);
                    await delay(100);
                }
            }

            // 3. Process remaining tokens
            if (batchFCM.length > 0) {
                const result = await processFCMBatch(batchFCM, broadcast.title, broadcast.message, broadcast.link);
                successCount += result.success;
                failureCount += result.failure;
                invalidTokens.push(...result.invalidTokens);
            }

            if (batchAPNS.length > 0) {
                const result = await processAPNSBatch(batchAPNS, broadcast.title, broadcast.message, broadcast.link);
                successCount += result.success;
                failureCount += result.failure;
                invalidTokens.push(...result.invalidTokens);
            }

            // 4. Cleanup dead/invalid tokens
            if (invalidTokens.length > 0) {
                logger.info(`[BroadcastWorker] Cleaning up ${invalidTokens.length} unreachable tokens`);
                await Device.updateMany({ fcmToken: { $in: invalidTokens } }, { fcmToken: '' });
            }

            // 5. Finalize doc
            broadcast.successCount = successCount;
            broadcast.failureCount = failureCount;
            broadcast.status = 'sent';
            broadcast.sentAt = new Date();
            await broadcast.save();

            logger.info(`[BroadcastWorker] Finished ${broadcastId}: ${successCount} sent, ${failureCount} failed.`);
            return { successCount, failureCount };

        } catch (e) {
            logger.error(`[BroadcastWorker] Failed ${broadcastId}:`, e);
            broadcast.status = 'failed';
            await broadcast.save();
            throw e;
        }
    },
    {
        connection,
        concurrency: 5 // Process 5 broadcasts concurrently at most
    }
);


// ─── Helpers ───────────────────────────────────────────────────────────

async function processFCMBatch(tokens, title, body, link = '') {
    let success = 0;
    let failure = 0;
    let invalidTokens = [];

    try {
        const message = {
            tokens,
            notification: {
                title: title || '',
                body: body || '',
            },
            data: {
                title: title || '',
                body: body || '',
                type: 'broadcast',
                link: link || '',
                click_action: 'FLUTTER_NOTIFICATION_CLICK',
            },
            android: {
                priority: 'high',
                notification: {
                    channelId: 'infexor_messages',
                    sound: 'notification_sound',
                    defaultSound: false,
                },
            },
            apns: {
                payload: {
                    aps: { sound: 'default' },
                },
            },
        };

        const response = await admin.messaging().sendEachForMulticast(message);

        success = response.successCount;
        failure = response.failureCount;

        if (failure > 0) {
            response.responses.forEach((resp, idx) => {
                if (!resp.success) {
                    const errCode = resp.error?.code;
                    if (errCode === 'messaging/invalid-registration-token' ||
                        errCode === 'messaging/registration-token-not-registered') {
                        invalidTokens.push(tokens[idx]);
                    }
                }
            });
        }
    } catch (err) {
        logger.error('[BroadcastWorker] FCM batch error:', err);
        failure = tokens.length;
    }

    return { success, failure, invalidTokens };
}

async function processAPNSBatch(tokens, title, body, link = '') {
    // APNs node module doesn't natively batch 500 cleanly like Firebase.
    // We loop and dispatch.
    let success = 0;
    let failure = 0;
    let invalidTokens = [];

    // Parallel map but wrapped in limit if needed
    await Promise.allSettled(tokens.map(async (token) => {
        try {
            await apnsService.sendMessagePush(token, title, body, { type: 'broadcast', link: link || '' });
            success++;
        } catch (err) {
            failure++;
            if (err.statusCode === 410 || err.reason === 'Unregistered') {
                invalidTokens.push(token);
            }
        }
    }));

    return { success, failure, invalidTokens };
}

async function updateProgress(broadcastId, success, failure) {
    await Broadcast.updateOne(
        { _id: broadcastId },
        { $set: { successCount: success, failureCount: failure } }
    );
}

const delay = ms => new Promise(res => setTimeout(res, ms));

broadcastWorker.on('failed', (job, err) => {
    logger.error(`[BroadcastWorker] Job ${job.id} failed: ${err.message}`);
});

module.exports = broadcastWorker;
