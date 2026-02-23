const { getRedis } = require('../config/redis');
const logger = require('../utils/logger');

const PRESENCE_PREFIX = 'presence:';
const PRESENCE_TTL = 120; // 2 minutes heartbeat window

// In-memory fallback
const memoryPresence = new Map();

/**
 * Set user online
 */
async function setOnline(userId) {
  const redis = getRedis();
  const key = `${PRESENCE_PREFIX}${userId}`;

  if (redis) {
    try {
      await redis.set(key, Date.now().toString(), 'EX', PRESENCE_TTL);
      return;
    } catch (err) {
      logger.warn('Redis setOnline fallback:', err.message);
    }
  }

  memoryPresence.set(key, { ts: Date.now(), expiresAt: Date.now() + PRESENCE_TTL * 1000 });
}

/**
 * Set user offline
 */
async function setOffline(userId) {
  const redis = getRedis();
  const key = `${PRESENCE_PREFIX}${userId}`;

  if (redis) {
    try {
      await redis.del(key);
      return;
    } catch (err) {
      logger.warn('Redis setOffline fallback:', err.message);
    }
  }

  memoryPresence.delete(key);
}

/**
 * Check if user is online
 */
async function isOnline(userId) {
  const redis = getRedis();
  const key = `${PRESENCE_PREFIX}${userId}`;

  if (redis) {
    try {
      const val = await redis.get(key);
      return val !== null;
    } catch (err) {
      logger.warn('Redis isOnline fallback:', err.message);
    }
  }

  const entry = memoryPresence.get(key);
  return entry ? entry.expiresAt > Date.now() : false;
}

/**
 * Heartbeat — refresh TTL
 */
async function heartbeat(userId) {
  await setOnline(userId);
}

/**
 * Get online status for multiple users
 */
async function getOnlineStatuses(userIds) {
  const result = {};
  const redis = getRedis();

  if (redis && userIds.length > 0) {
    try {
      const pipeline = redis.pipeline();
      userIds.forEach((id) => pipeline.get(`${PRESENCE_PREFIX}${id}`));
      const results = await pipeline.exec();
      userIds.forEach((id, i) => {
        result[id] = results[i][1] !== null;
      });
      return result;
    } catch (err) {
      logger.warn('Redis getOnlineStatuses fallback:', err.message);
    }
  }

  userIds.forEach((id) => {
    const entry = memoryPresence.get(`${PRESENCE_PREFIX}${id}`);
    result[id] = entry ? entry.expiresAt > Date.now() : false;
  });

  return result;
}

module.exports = {
  setOnline,
  setOffline,
  isOnline,
  heartbeat,
  getOnlineStatuses,
};
