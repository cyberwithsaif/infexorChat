const rateLimit = require('express-rate-limit');
const env = require('../config/env');

const globalLimiter = rateLimit({
  windowMs: env.rateLimit.windowMs,
  max: 500, // Increased from 100 — was throttling normal app usage
  message: {
    success: false,
    message: 'Too many requests, please try again later',
  },
  standardHeaders: true,
  legacyHeaders: false,
});

// Stricter limiter for auth endpoints
const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 10,
  message: {
    success: false,
    message: 'Too many authentication attempts, please try again later',
  },
  standardHeaders: true,
  legacyHeaders: false,
});

// OTP-specific limiter
const otpLimiter = rateLimit({
  windowMs: 60 * 1000, // 1 minute
  max: 3,
  message: {
    success: false,
    message: 'Too many OTP requests, please wait before trying again',
  },
  standardHeaders: true,
  legacyHeaders: false,
});
// Message/Chat generic limiter
const messageLimiter = rateLimit({
  windowMs: 60 * 1000, // 1 minute
  max: 60, // 60 requests per minute
  message: {
    success: false,
    message: 'Too many messages sent, please slow down',
  },
  standardHeaders: true,
  legacyHeaders: false,
});

// Media upload limiter (prevents bandwidth exhaustion)
const mediaLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 30, // Max 30 media uploads per 15 minutes
  message: {
    success: false,
    message: 'Media upload limit reached, please try again later',
  },
  standardHeaders: true,
  legacyHeaders: false,
});

// Group creation / heavy action limiter
const groupCreateLimiter = rateLimit({
  windowMs: 60 * 60 * 1000, // 1 hour
  max: 10, // Max 10 groups created per hour
  message: {
    success: false,
    message: 'Too many groups created, please try again later',
  },
  standardHeaders: true,
  legacyHeaders: false,
});

module.exports = {
  globalLimiter,
  authLimiter,
  otpLimiter,
  messageLimiter,
  mediaLimiter,
  groupCreateLimiter
};
