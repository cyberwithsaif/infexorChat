const express = require('express');
const { auth } = require('../middleware/auth');
const { groupCreateLimiter } = require('../middleware/rateLimiter');
const groupController = require('../controllers/groupController');

const router = express.Router();

// All routes require authentication
router.use(auth);

// Group CRUD
router.post('/create', groupCreateLimiter, groupController.createGroup);
router.get('/:groupId', groupController.getGroupInfo);
router.put('/:groupId', groupController.updateGroup);
router.put('/:groupId/settings', groupController.updateSettings);

// Member management
router.post('/:groupId/members', groupController.addMembers);
router.delete('/:groupId/members/:memberId', groupController.removeMember);
router.put('/:groupId/members/:memberId/role', groupController.changeRole);

// Invite link
router.post('/:groupId/invite-link', groupController.generateInviteLink);
router.put('/:groupId/invite-link', groupController.toggleInviteLink);
router.post('/join/:inviteLink', groupController.joinViaLink);

// Leave & mute
router.post('/:groupId/leave', groupController.leaveGroup);
router.put('/:groupId/mute', groupController.muteGroup);

module.exports = router;
