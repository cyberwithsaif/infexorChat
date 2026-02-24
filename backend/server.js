const http = require('http');
const app = require('./src/app');
const env = require('./src/config/env');
const logger = require('./src/utils/logger');
const connectDB = require('./src/config/db');
const { connectRedis } = require('./src/config/redis');
const { initSocket } = require('./src/config/socket');
const { startMediaCleanupCron } = require('./src/utils/mediaCron');
const User = require('./src/models/User');

const server = http.createServer(app);

const start = async () => {
  // Connect to MongoDB
  await connectDB();

  // Reset all users to offline on server startup (cleans stale presence from crashes/restarts)
  try {
    const result = await User.updateMany(
      { isOnline: true },
      { $set: { isOnline: false, lastSeen: new Date() } }
    );
    if (result.modifiedCount > 0) {
      logger.info(`Reset ${result.modifiedCount} stale online users to offline`);
    }
  } catch (err) {
    logger.warn('Failed to reset online statuses:', err.message);
  }

  // Auto-Initialize/Update AI Bot Profile
  if (env.ai && env.ai.enabled && env.ai.botUserId) {
    try {
      const botCheck = await User.findById(env.ai.botUserId);
      const botData = {
        name: 'AI BOT',
        phone: '+01000000000',
        avatar: 'https://api.dicebear.com/9.x/bottts/png?seed=InfexorAI&backgroundColor=00C853',
        about: 'I am your advanced AI assistant.',
        status: 'online',
        isProfileComplete: true
      };

      if (!botCheck) {
        botData._id = env.ai.botUserId;
        await User.create(botData);
        logger.info(`[Startup] Created missing AI BOT user profile in DB.`);
      } else if (botCheck.name !== 'AI BOT' || !botCheck.avatar) {
        await User.findByIdAndUpdate(env.ai.botUserId, botData);
        logger.info(`[Startup] Updated AI BOT user profile (name/avatar) in DB.`);
      }
    } catch (err) {
      logger.error(`[Startup] Failed to initialize AI BOT profile: ${err.message}`);
    }
  }

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
