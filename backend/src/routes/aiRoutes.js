const express = require('express');
const rateLimit = require('express-rate-limit');
const aiController = require('../controllers/aiController');

const router = express.Router();

// Strict rate limiter for AI endpoint: 20 requests per minute
const aiLimiter = rateLimit({
    windowMs: 60 * 1000, // 1 minute
    max: 20,
    message: {
        success: false,
        message: 'Too many AI requests, please try again later',
    },
    standardHeaders: true,
    legacyHeaders: false,
});

// POST /api/ai/send-ai-message — receive AI reply from n8n
router.post('/send-ai-message', aiLimiter, aiController.sendAIMessage);

// GET /api/ai/health — AI subsystem health check
router.get('/health', aiController.aiHealth);

module.exports = router;
