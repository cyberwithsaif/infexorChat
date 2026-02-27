const redisClient = require('../config/redis').client;
const logger = require('../utils/logger');
const ApiResponse = require('../utils/apiResponse');

/**
 * Abuse Detection Middleware
 * Identifies and mitigates anomalous activity like spam or flooding.
 */

// 1. Same Message Flooding Detection (Spam Protection)
const detectMessageSpam = async (req, res, next) => {
    if (!redisClient) return next(); // Skip if Redis is down

    try {
        const userId = req.user.userId;
        const { content, type } = req.body;

        // Only text messages for spam hash checking
        if (type !== 'text' || !content) return next();

        // Create a basic hash of the message to identify identical spam
        const messageHash = Buffer.from(content).toString('base64').substring(0, 32);

        const redisKey = `abuse:spam:${userId}:${messageHash}`;

        // Increment count of this exact message sent by this user
        const count = await redisClient.incr(redisKey);

        if (count === 1) {
            // Expire the tracker after 5 minutes
            await redisClient.expire(redisKey, 300);
        }

        // If user sends the EXACT same message > 20 times in 5 minutes
        if (count > 20) {
            logger.warn(`Spam detected: User ${userId} sent identical message > 20 times`);

            // Auto-block the user temporarily (1 hour penalty box)
            const penaltyKey = `abuse:penalty:${userId}`;
            await redisClient.set(penaltyKey, 'spam', 'EX', 3600);

            return ApiResponse.forbidden(res, 'Account temporarily restricted due to anomalous activity. Please try again later.');
        }

        next();
    } catch (err) {
        logger.error('Abuse detection error (spam):', err);
        next(); // Fail open so chat isn't completely broken
    }
};

// 2. Penalty Box Check (Prevents restricted users from taking actions)
const verifyAcctStanding = async (req, res, next) => {
    if (!redisClient) return next();

    try {
        const userId = req.user.userId;
        const penaltyKey = `abuse:penalty:${userId}`;

        const restriction = await redisClient.get(penaltyKey);

        if (restriction) {
            return ApiResponse.forbidden(res, `Account restricted due to policy violation (${restriction})`);
        }

        next();
    } catch (err) {
        logger.error('Abuse detection error (penalty box):', err);
        next();
    }
};

module.exports = {
    detectMessageSpam,
    verifyAcctStanding
};
