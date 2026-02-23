const express = require('express');
const { body } = require('express-validator');
const validate = require('../middleware/validate');
const { auth } = require('../middleware/auth');
const userController = require('../controllers/userController');

const router = express.Router();

// All user routes require auth
router.use(auth);

// Get profile
router.get('/profile', userController.getProfile);

// Get all media from all user chats
router.get('/media', userController.getAllMedia);

// Update profile
router.put(
  '/profile',
  [
    body('name')
      .optional()
      .trim()
      .isLength({ min: 1, max: 50 })
      .withMessage('Name must be 1-50 characters'),
    body('about')
      .optional()
      .trim()
      .isLength({ max: 150 })
      .withMessage('About must be under 150 characters'),
  ],
  validate,
  userController.updateProfile
);

// FCM token management
router.post('/fcm-token', userController.registerFcmToken);
router.delete('/fcm-token', userController.removeFcmToken);

// Privacy settings
router.put('/privacy', userController.updatePrivacy);

// Block/unblock users
router.post('/block/:userId', userController.blockUser);
router.delete('/block/:userId', userController.unblockUser);
router.get('/blocked', userController.getBlockedUsers);
router.get('/block/:userId/status', userController.checkBlockStatus);

module.exports = router;
