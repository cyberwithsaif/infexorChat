const express = require('express');
const { body } = require('express-validator');
const validate = require('../middleware/validate');
const { adminAuth } = require('../middleware/auth');
const { authLimiter } = require('../middleware/rateLimiter');
const adminAuthController = require('../controllers/adminAuthController');
const adminController = require('../controllers/adminController');

const router = express.Router();

// ─── AUTH (public) ───

router.post(
  '/auth/login',
  authLimiter,
  [
    body('username').notEmpty().trim().withMessage('Username is required'),
    body('password').notEmpty().withMessage('Password is required'),
  ],
  validate,
  adminAuthController.login
);

router.post(
  '/auth/create-first',
  [
    body('username').notEmpty().trim().isLength({ min: 3 }).withMessage('Username min 3 chars'),
    body('password').isLength({ min: 6 }).withMessage('Password min 6 chars'),
  ],
  validate,
  adminAuthController.createFirst
);

// ─── PROTECTED ROUTES (require admin auth) ───

router.use(adminAuth);

// Dashboard
router.get('/dashboard/stats', adminController.getDashboardStats);

// User Management
router.get('/users', adminController.getUsers);
router.get('/users/:id', adminController.getUserDetail);
router.put('/users/:id/status', adminController.changeUserStatus);
router.post('/users/:id/force-logout', adminController.forceLogout);

// Reports
router.get('/reports', adminController.getReports);
router.put('/reports/:id', adminController.resolveReport);

// Broadcasts
router.post('/broadcasts', adminController.sendBroadcast);
router.get('/broadcasts', adminController.getBroadcasts);

module.exports = router;
