const express = require('express');
const { body } = require('express-validator');
const validate = require('../middleware/validate');
const { auth } = require('../middleware/auth');
const { authLimiter, otpLimiter } = require('../middleware/rateLimiter');
const authController = require('../controllers/authController');

const router = express.Router();

// Send OTP
router.post(
  '/send-otp',
  otpLimiter,
  [
    body('phone').notEmpty().withMessage('Phone number is required'),
    body('countryCode').notEmpty().withMessage('Country code is required'),
  ],
  validate,
  authController.sendOtp
);

// Verify OTP
router.post(
  '/verify-otp',
  authLimiter,
  [
    body('phone').notEmpty().withMessage('Phone number is required'),
    body('countryCode').notEmpty().withMessage('Country code is required'),
    body('otp').isLength({ min: 6, max: 6 }).withMessage('OTP must be 6 digits'),
  ],
  validate,
  authController.verifyOtp
);

// Retry OTP
router.post(
  '/retry-otp',
  otpLimiter,
  [
    body('reqId').notEmpty().withMessage('Request ID is required'),
  ],
  validate,
  authController.retryOtp
);

// Refresh token
router.post(
  '/refresh-token',
  [body('refreshToken').notEmpty().withMessage('Refresh token is required')],
  validate,
  authController.refreshToken
);

// Logout (requires auth)
router.post('/logout', auth, authController.logout);

// Logout all devices (requires auth)
router.post('/logout-all', auth, authController.logoutAll);

// Update FCM token (requires auth)
router.put('/fcm-token', auth, authController.updateFcmToken);

module.exports = router;
