const express = require('express');
const { body } = require('express-validator');
const validate = require('../middleware/validate');
const { auth } = require('../middleware/auth');
const chatController = require('../controllers/chatController');
const messageController = require('../controllers/messageController');

const router = express.Router();

// All chat routes require auth
router.use(auth);

// Create or get 1:1 chat
router.post(
  '/create',
  [body('participantId').notEmpty().withMessage('participantId is required')],
  validate,
  chatController.createChat
);

// List user's chats
router.get('/', chatController.getChats);

// Starred messages
router.get('/starred', messageController.getStarredMessages);

// Get media gallery for a chat
router.get('/:chatId/media', chatController.getChatMedia);

// Get messages for a chat
router.get('/:chatId/messages', chatController.getMessages);

// Search messages in a chat
router.get('/:chatId/messages/search', messageController.searchMessages);

// Delete message
router.delete('/:chatId/messages/:messageId', messageController.deleteMessage);

// React to message
router.post('/:chatId/messages/:messageId/react',
  [body('emoji').notEmpty().withMessage('Emoji is required')],
  validate,
  messageController.reactToMessage
);

// Star/unstar message
router.post('/:chatId/messages/:messageId/star', messageController.starMessage);

// Forward message
router.post('/:chatId/messages/:messageId/forward',
  [body('targetChatId').notEmpty().withMessage('targetChatId is required')],
  validate,
  messageController.forwardMessage
);

module.exports = router;
