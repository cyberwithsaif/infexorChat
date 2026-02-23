const Redis = require('ioredis');
const logger = require('../utils/logger');
const env = require('./env');

let redisClient = null;

const connectRedis = () => {
  try {
    redisClient = new Redis({
      host: env.redis.host,
      port: env.redis.port,
      password: env.redis.password,
      retryStrategy: (times) => {
        if (times > 3) {
          logger.warn('Redis: Max retries reached, running without Redis');
          return null;
        }
        return Math.min(times * 200, 2000);
      },
      maxRetriesPerRequest: 3,
    });

    redisClient.on('connect', () => {
      logger.info('Redis connected successfully');
    });

    redisClient.on('error', (err) => {
      logger.warn('Redis error:', err.message);
    });
  } catch (error) {
    logger.warn('Redis unavailable, running without Redis:', error.message);
    redisClient = null;
  }

  return redisClient;
};

const getRedis = () => redisClient;

module.exports = { connectRedis, getRedis };
