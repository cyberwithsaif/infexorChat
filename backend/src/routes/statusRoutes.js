const express = require('express');
const { auth } = require('../middleware/auth');
const statusController = require('../controllers/statusController');

const router = express.Router();

// All status routes require auth
router.use(auth);

// Create a status
router.post('/', statusController.createStatus);

// Get my own statuses
router.get('/mine', statusController.getMyStatuses);

// Get contacts' statuses
router.get('/contacts', statusController.getContactStatuses);

// Mark status as viewed
router.post('/:id/view', statusController.viewStatus);

// Delete a status
router.delete('/:id', statusController.deleteStatus);

module.exports = router;
