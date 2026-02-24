const dotenv = require('dotenv');
dotenv.config();

module.exports = {
  nodeEnv: process.env.NODE_ENV || 'development',
  port: parseInt(process.env.PORT, 10) || 5000,

  // MongoDB
  mongodbUri: process.env.MONGODB_URI || 'mongodb://localhost:27017/infexor_chat',

  // Redis
  redis: {
    host: process.env.REDIS_HOST || '127.0.0.1',
    port: parseInt(process.env.REDIS_PORT, 10) || 6379,
    password: process.env.REDIS_PASSWORD || undefined,
  },

  // JWT
  jwt: {
    secret: process.env.JWT_SECRET || 'default_secret',
    expiresIn: process.env.JWT_EXPIRES_IN || '7d',
    refreshSecret: process.env.JWT_REFRESH_SECRET || 'default_refresh_secret',
    refreshExpiresIn: process.env.JWT_REFRESH_EXPIRES_IN || '30d',
  },

  // Admin JWT
  adminJwt: {
    secret: process.env.ADMIN_JWT_SECRET || 'default_admin_secret',
    expiresIn: process.env.ADMIN_JWT_EXPIRES_IN || '1d',
  },

  // CORS
  corsOrigin: process.env.CORS_ORIGIN || '*',

  // Rate Limiting
  rateLimit: {
    windowMs: parseInt(process.env.RATE_LIMIT_WINDOW_MS, 10) || 900000,
    max: parseInt(process.env.RATE_LIMIT_MAX, 10) || 100,
  },

  // Uploads
  uploads: {
    dir: process.env.UPLOADS_DIR || 'uploads',
    maxFileSize: {
      image: parseInt(process.env.MAX_IMAGE_SIZE, 10) || 100 * 1024 * 1024,      // 100 MB
      video: parseInt(process.env.MAX_VIDEO_SIZE, 10) || 500 * 1024 * 1024,      // 500 MB
      audio: parseInt(process.env.MAX_AUDIO_SIZE, 10) || 100 * 1024 * 1024,      // 100 MB
      voice: parseInt(process.env.MAX_VOICE_SIZE, 10) || 100 * 1024 * 1024,      // 100 MB
      document: parseInt(process.env.MAX_DOCUMENT_SIZE, 10) || 100 * 1024 * 1024, // 100 MB
    },
  },

  // AI Bot / n8n / Gemini
  ai: {
    webhookUrl: process.env.N8N_WEBHOOK_URL || 'http://72.61.171.190:5678/webhook/infexor-ai-reply',
    webhookSecret: process.env.N8N_WEBHOOK_SECRET || 'infexor-secure-ai-secret-2025',
    botUserId: process.env.AI_BOT_USER_ID || '',
    enabled: process.env.AI_ENABLED === 'true',
    geminiKey: process.env.GEMINI_API_KEY || '',
  },
};
