const express = require('express');
const helmet = require('helmet');
const cors = require('cors');
const compression = require('compression');
const mongoSanitize = require('express-mongo-sanitize');
const hpp = require('hpp');
const path = require('path');
const env = require('./config/env');
const { globalLimiter } = require('./middleware/rateLimiter');
const errorHandler = require('./middleware/errorHandler');
const routes = require('./routes');
const ApiResponse = require('./utils/apiResponse');
const { uploadsDir } = require('./config/upload');

const app = express();

// Security middleware
app.use(helmet({
  crossOriginResourcePolicy: { policy: 'cross-origin' },
  contentSecurityPolicy: false,
}));

// CORS
app.use(cors({
  origin: env.corsOrigin,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH'],
  allowedHeaders: ['Content-Type', 'Authorization'],
}));

// Compression
app.use(compression());

// Body parsing
app.use(express.json({ limit: '100mb' }));
app.use(express.urlencoded({ extended: true, limit: '100mb' }));

const xss = require('xss-clean');

// Security: prevent MongoDB injection & HTTP parameter pollution
// express-mongo-sanitize crashes on Express 5+ (req.query is read-only getter)
// So we only sanitize req.body and req.params manually
app.use((req, res, next) => {
  if (req.body) {
    req.body = mongoSanitize.sanitize(req.body);
  }
  if (req.params) {
    req.params = mongoSanitize.sanitize(req.params);
  }
  next();
});
app.use(xss()); // Sanitize against XSS
app.use(hpp());

// Removed: app.use('/uploads', express.static(path.resolve(uploadsDir)));
// Media is now served securely via /api/upload/:category/:filename endpoint

// Serve admin panel frontend
const adminPath = path.resolve(__dirname, '../admin');
app.use('/admin', express.static(adminPath));

// Rate limiting
app.use('/api', globalLimiter);

// API routes
app.use('/api', routes);

// 404 handler
app.use((req, res) => {
  ApiResponse.notFound(res, `Route ${req.method} ${req.url} not found`);
});

// Error handler
app.use(errorHandler);

module.exports = app;
