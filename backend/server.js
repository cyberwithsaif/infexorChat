const http = require('http');
const app = require('./src/app');
const env = require('./src/config/env');
const logger = require('./src/utils/logger');
const connectDB = require('./src/config/db');
const { connectRedis } = require('./src/config/redis');
const { initSocket } = require('./src/config/socket');
const { startMediaCleanupCron } = require('./src/utils/mediaCron');

const server = http.createServer(app);

const start = async () => {
  // Connect to MongoDB
  await connectDB();

  // Connect to Redis (graceful fallback)
  connectRedis();

  // Start the background cron job to clear expired media
  startMediaCleanupCron();

  // Initialize Socket.io
  initSocket(server);

  // Start server
  server.listen(env.port, () => {
    logger.info(`Infexor Chat API running on port ${env.port} [${env.nodeEnv}]`);
  });
};

// Graceful shutdown
const shutdown = (signal) => {
  logger.info(`${signal} received, shutting down gracefully...`);
  server.close(() => {
    logger.info('HTTP server closed');
    process.exit(0);
  });
};

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));

process.on('unhandledRejection', (reason) => {
  logger.error('Unhandled Rejection:', reason);
});

start();
