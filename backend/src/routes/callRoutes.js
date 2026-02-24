const express = require('express');
const router = express.Router();
const callController = require('../controllers/callController');
const { auth } = require('../middleware/auth');

// Get call history
router.get('/', auth, callController.getCallHistory);

// Record a new call
router.post('/', auth, callController.recordCall);

module.exports = router;
