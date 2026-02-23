const express = require('express');
const { body } = require('express-validator');
const validate = require('../middleware/validate');
const { auth } = require('../middleware/auth');
const contactController = require('../controllers/contactController');

const router = express.Router();

// All contact routes require auth
router.use(auth);

// Sync contacts
router.post(
  '/sync',
  [
    body('contacts')
      .isArray({ min: 1 })
      .withMessage('Contacts array is required'),
    body('contacts.*.phoneHash')
      .notEmpty()
      .withMessage('Each contact must have a phoneHash'),
  ],
  validate,
  contactController.syncContacts
);

// Get contacts
router.get('/', contactController.getContacts);

module.exports = router;
