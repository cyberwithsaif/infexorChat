/**
 * Standalone BullMQ worker process.
 * Handles both push notifications and broadcast notifications.
 * Run as a separate PM2 app: pm2 start src/services/pushWorkerProcess.js --name infexor-push-worker
 */

const dotenv = require('dotenv');
dotenv.config();

const { Worker } = require('bullmq');
const mongoose = require('mongoose');
const logger = require('../utils/logger');

// Initialize Firebase Admin SDK for push notifications
const admin = require('firebase-admin');
let firebaseInitialized = false;
try {
    const serviceAccount = require('../../infexorchat-firebase-adminsdk.json');
    admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
    });
    firebaseInitialized = true;
    logger.info('[PushWorker] Firebase Admin SDK initialized');
} catch (err) {
    logger.error('[PushWorker] Firebase init failed:', err.message);
}

const QUEUE_NAME = 'push-notifications';

// Lazy-load notification service
let notificationService;
function getNotificationService() {
    if (!notificationService) {
        notificationService = require('./notificationService');
    }
    return notificationService;
}

const redisConnection = {
    host: process.env.REDIS_HOST || '127.0.0.1',
    port: parseInt(process.env.REDIS_PORT, 10) || 6379,
    password: process.env.REDIS_PASSWORD || undefined,
};

// ─── Push notification worker ─────────────────────────────────────────────────
const worker = new Worker(
    QUEUE_NAME,
    async (job) => {
        if (!firebaseInitialized) {
            logger.warn('[PushWorker] Firebase not initialized, skipping job');
            return;
        }

        const ns = getNotificationService();
        const { name: type, data } = job;

        switch (type) {
            case 'message':
                await ns.sendToUser(data.userId, data.title, data.body, data.payload);
                break;
            case 'call':
                await ns.sendCallToUser(data.userId, data.callData);
                break;
            case 'callControl':
                await ns.sendCallControlToUser(data.userId, data.controlData);
                break;
            default:
                logger.warn(`[PushWorker] Unknown job type: ${type}`);
        }
    },
    {
        connection: redisConnection,
        concurrency: 10,
        limiter: { max: 100, duration: 1000 },
    }
);

worker.on('completed', (job) => {
    logger.debug(`[PushWorker] Job ${job.id} (${job.name}) completed`);
});
worker.on('failed', (job, err) => {
    logger.error(`[PushWorker] Job ${job?.id} (${job?.name}) failed: ${err.message}`);
});
worker.on('error', (err) => {
    logger.error('[PushWorker] Worker error:', err.message);
});

logger.info('[PushWorker] Push notification worker started, waiting for jobs...');

// ─── Broadcast worker (requires MongoDB) ─────────────────────────────────────
const mongoUri = process.env.MONGODB_URI || process.env.MONGO_URI;
if (mongoUri) {
    mongoose.connect(mongoUri)
        .then(() => {
            logger.info('[PushWorker] MongoDB connected — starting broadcast worker');
            require('../workers/broadcastWorker');
            logger.info('[PushWorker] Broadcast worker started on broadcast-queue');
        })
        .catch(err => {
            logger.error('[PushWorker] MongoDB connection failed (broadcast worker disabled):', err.message);
        });
} else {
    logger.warn('[PushWorker] MONGODB_URI not set — broadcast worker disabled');
}

// ─── Graceful shutdown ────────────────────────────────────────────────────────
async function shutdown() {
    logger.info('[PushWorker] Shutting down workers...');
    await worker.close();
    await mongoose.disconnect();
    process.exit(0);
}
process.on('SIGTERM', shutdown);
process.on('SIGINT', shutdown);
