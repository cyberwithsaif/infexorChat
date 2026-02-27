const { Queue } = require('bullmq');
const env = require('./env');

const connection = {
    host: env.redisHost || '127.0.0.1',
    port: env.redisPort || 6379,
    password: env.redisPassword || undefined,
};

// Main queue for processing broadcast notifications
const broadcastQueue = new Queue('broadcast-queue', { connection });

module.exports = {
    connection,
    broadcastQueue,
};
