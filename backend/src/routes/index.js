const express = require('express');
const ApiResponse = require('../utils/apiResponse');
const authRoutes = require('./authRoutes');
const userRoutes = require('./userRoutes');
const adminRoutes = require('./adminRoutes');
const contactRoutes = require('./contactRoutes');
const chatRoutes = require('./chatRoutes');
const uploadRoutes = require('./uploadRoutes');
const groupRoutes = require('./groupRoutes');
const statusRoutes = require('./statusRoutes');

const router = express.Router();

// Health check
router.get('/health', (req, res) => {
  ApiResponse.success(res, {
    status: 'ok',
    uptime: process.uptime(),
    timestamp: new Date().toISOString(),
  }, 'Server is healthy');
});

// Route mounts
router.use('/auth', authRoutes);
router.use('/users', userRoutes);
router.use('/admin', adminRoutes);
router.use('/contacts', contactRoutes);
router.use('/chats', chatRoutes);
router.use('/upload', uploadRoutes);
router.use('/groups', groupRoutes);
router.use('/status', statusRoutes);

module.exports = router;
