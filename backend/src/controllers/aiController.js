const crypto = require('crypto');
const { Message, Chat, User } = require('../models');
const { getIO } = require('../config/socket');
const env = require('../config/env');
const logger = require('../utils/logger');
const ApiResponse = require('../utils/apiResponse');

// In-memory rate-limit map: userId -> last request timestamp
const rateLimitMap = new Map();
const RATE_LIMIT_COOLDOWN_MS = 3000; // 3 seconds per user

/**
 * Validate webhook secret via HMAC-SHA256 or simple header match
 */
function validateWebhookSecret(req) {
    const secret = req.headers['x-webhook-secret'];
    if (!secret || !env.ai.webhookSecret) return false;
    return crypto.timingSafeEqual(
        Buffer.from(secret),
        Buffer.from(env.ai.webhookSecret)
    );
}

/**
 * POST /api/ai/send-ai-message
 * Receives AI-generated reply from n8n and injects it into the chat
 */
exports.sendAIMessage = async (req, res, next) => {
    try {
        // 1. Validate webhook secret
        if (!validateWebhookSecret(req)) {
            logger.warn('[AI] Invalid webhook secret attempt');
            return ApiResponse.unauthorized(res, 'Invalid webhook secret');
        }

        const { chatId, userId, message, isAI } = req.body;

        // 2. Validate required fields
        if (!chatId || !userId || !message) {
            return ApiResponse.badRequest(res, 'chatId, userId, and message are required');
        }

        // 3. Validate message content
        const trimmedMessage = (message || '').trim();
        if (!trimmedMessage || trimmedMessage.length === 0) {
            return ApiResponse.badRequest(res, 'Message cannot be empty');
        }

        if (trimmedMessage.length > 2000) {
            return ApiResponse.badRequest(res, 'Message too long (max 2000 chars)');
        }

        // 4. Anti-loop: prevent AI from replying to AI
        if (isAI === true) {
            logger.info('[AI] Blocked: AI-to-AI loop prevented');
            return ApiResponse.success(res, null, 'AI-to-AI loop blocked');
        }

        // 5. Rate limiting per user
        const now = Date.now();
        const lastRequest = rateLimitMap.get(userId);
        if (lastRequest && (now - lastRequest) < RATE_LIMIT_COOLDOWN_MS) {
            logger.info(`[AI] Rate limited: user ${userId}`);
            return ApiResponse.tooMany(res, 'AI reply rate limited. Please wait.');
        }
        rateLimitMap.set(userId, now);

        // 6. Verify chat exists
        const chat = await Chat.findById(chatId);
        if (!chat) {
            return ApiResponse.notFound(res, 'Chat not found');
        }

        // 7. Get or validate bot user ID
        const botUserId = env.ai.botUserId;
        if (!botUserId) {
            logger.error('[AI] AI_BOT_USER_ID not configured');
            return ApiResponse.error(res, 'AI bot not configured', 500);
        }

        // 8. Emit typing indicator (simulates natural behavior)
        try {
            const io = getIO();
            chat.participants.forEach((pid) => {
                const p = pid.toString();
                if (p !== botUserId) {
                    io.to(`user:${p}`).emit('typing:start', {
                        chatId,
                        userId: botUserId,
                    });
                }
            });
        } catch (err) {
            logger.warn('[AI] Could not emit typing indicator:', err.message);
        }

        // 9. Simulate typing delay (500-1500ms based on message length)
        const typingDelay = Math.min(1500, Math.max(500, trimmedMessage.length * 10));
        await new Promise((resolve) => setTimeout(resolve, typingDelay));

        // 10. Stop typing indicator
        try {
            const io = getIO();
            chat.participants.forEach((pid) => {
                const p = pid.toString();
                if (p !== botUserId) {
                    io.to(`user:${p}`).emit('typing:stop', {
                        chatId,
                        userId: botUserId,
                    });
                }
            });
        } catch (err) {
            // ignore
        }

        // 11. Create AI message in MongoDB
        const aiMessage = await Message.create({
            chatId,
            senderId: botUserId,
            type: 'text',
            content: trimmedMessage,
            isAI: true,
            status: 'sent',
        });

        // 12. Update chat lastMessage
        await Chat.findByIdAndUpdate(chatId, {
            lastMessage: aiMessage._id,
            lastMessageAt: aiMessage.createdAt,
        });

        // 13. Populate and broadcast via Socket.IO
        const populatedMsg = await Message.findById(aiMessage._id)
            .populate('senderId', 'name avatar')
            .lean();

        try {
            const io = getIO();
            chat.participants.forEach((pid) => {
                const p = pid.toString();
                if (p !== botUserId) {
                    io.to(`user:${p}`).emit('message:new', populatedMsg);
                }
            });
        } catch (err) {
            logger.warn('[AI] Could not broadcast AI message via socket:', err.message);
        }

        logger.info(`[AI] Reply sent to chat ${chatId}: "${trimmedMessage.substring(0, 50)}..."`);

        return ApiResponse.success(res, { message: populatedMsg }, 'AI reply sent');
    } catch (error) {
        logger.error('[AI] sendAIMessage error:', error);
        next(error);
    }
};

/**
 * GET /api/ai/health
 * Health check for AI subsystem
 */
exports.aiHealth = (req, res) => {
    return ApiResponse.success(res, {
        enabled: env.ai.enabled,
        botUserId: env.ai.botUserId ? 'configured' : 'NOT SET',
        webhookUrl: env.ai.webhookUrl ? 'configured' : 'NOT SET',
    }, 'AI subsystem status');
};

// Cleanup stale rate-limit entries every 5 minutes
setInterval(() => {
    const now = Date.now();
    for (const [key, timestamp] of rateLimitMap.entries()) {
        if (now - timestamp > 60000) {
            rateLimitMap.delete(key);
        }
    }
}, 5 * 60 * 1000);
