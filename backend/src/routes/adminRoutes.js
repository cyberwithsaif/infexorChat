const express = require('express');
const { body } = require('express-validator');
const validate = require('../middleware/validate');
const { adminAuth } = require('../middleware/auth');
const { authLimiter } = require('../middleware/rateLimiter');
const adminAuthController = require('../controllers/adminAuthController');
const adminController = require('../controllers/adminController');

const router = express.Router();

// ─── AUTH (public) ───
router.post('/auth/login', authLimiter,
    [body('username').notEmpty().trim(), body('password').notEmpty()],
    validate, adminAuthController.login);

router.post('/auth/create-first',
    [body('username').notEmpty().trim().isLength({ min: 3 }), body('password').isLength({ min: 6 })],
    validate, adminAuthController.createFirst);

// ─── PROTECTED ROUTES ───
router.use(adminAuth);

// Dashboard
router.get('/dashboard/stats', adminController.getDashboardStats);
router.get('/dashboard/live', adminController.getLiveMetrics);

// User Management
router.get('/users', adminController.getUsers);
router.get('/users/:id', adminController.getUserDetail);
router.put('/users/:id/status', adminController.changeUserStatus);
router.post('/users/:id/force-logout', adminController.forceLogout);
router.delete('/users/:id', adminController.deleteUser);
router.post('/users/:id/reset-rate-limit', adminController.resetUserRateLimit);

// Call Analytics
router.get('/calls/active', adminController.getActiveCalls);
router.get('/calls/analytics', adminController.getCallAnalytics);
router.post('/calls/:id/force-end', adminController.forceEndCall);

// Chat Analytics
router.get('/chats/analytics', adminController.getChatAnalytics);

// Server Status
router.get('/server/status', adminController.getServerStatus);

// Storage & Media
router.get('/storage/stats', adminController.getStorageStats);
router.get('/storage/browse', adminController.browseMedia);
router.delete('/storage/media', adminController.deleteMedia);

// TURN Monitoring
router.get('/turn/status', adminController.getTurnStatus);

// Security
router.get('/security/events', adminController.getSecurityEvents);

// Alerts
router.get('/alerts/config', adminController.getAlertConfig);
router.put('/alerts/config', adminController.updateAlertConfig);

// Reports
router.get('/reports', adminController.getReports);
router.put('/reports/:id', adminController.resolveReport);

// Broadcasts
const rateLimit = require('express-rate-limit');
const broadcastLimiter = rateLimit({
    windowMs: 60 * 60 * 1000,
    max: 3,
    message: { success: false, message: 'Too many broadcasts sent. Maximum 3 per hour.' }
});

router.post('/broadcasts', broadcastLimiter, adminController.sendBroadcast);
router.get('/broadcasts', adminController.getBroadcasts);
router.get('/broadcasts/stats', adminController.getBroadcastStats);

module.exports = router;
