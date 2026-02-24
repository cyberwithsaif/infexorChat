const { User } = require('../models');
const ApiResponse = require('../utils/apiResponse');
const notificationService = require('../services/notificationService');

/**
 * GET /users/profile
 * Get current user's profile
 */
exports.getProfile = async (req, res, next) => {
  try {
    const user = await User.findById(req.user.userId).select('-blocked -fcmTokens -phoneHash');

    if (!user) {
      return ApiResponse.notFound(res, 'User not found');
    }

    return ApiResponse.success(res, { user });
  } catch (error) {
    next(error);
  }
};

/**
 * PUT /users/profile
 * Update profile (name, about, avatar)
 */
exports.updateProfile = async (req, res, next) => {
  try {
    const { name, about, avatar } = req.body;
    const updates = {};

    if (name !== undefined) updates.name = name;
    if (about !== undefined) updates.about = about;
    if (avatar !== undefined) updates.avatar = avatar;

    // Mark profile as complete if name is set
    if (name && name.trim().length > 0) {
      updates.isProfileComplete = true;
    }

    const user = await User.findByIdAndUpdate(
      req.user.userId,
      { $set: updates },
      { new: true, runValidators: true }
    ).select('-blocked -fcmTokens -phoneHash');

    if (!user) {
      return ApiResponse.notFound(res, 'User not found');
    }

    return ApiResponse.success(res, { user }, 'Profile updated');
  } catch (error) {
    next(error);
  }
};

// ─── FCM TOKEN MANAGEMENT ───

/**
 * POST /users/fcm-token
 * Register FCM token for push notifications
 */
exports.registerFcmToken = async (req, res, next) => {
  try {
    const { token } = req.body;
    if (!token) return ApiResponse.badRequest(res, 'Token is required');

    await notificationService.registerToken(req.user.userId, token);
    return ApiResponse.success(res, null, 'FCM token registered');
  } catch (error) {
    next(error);
  }
};

/**
 * DELETE /users/fcm-token
 * Remove FCM token (on logout)
 */
exports.removeFcmToken = async (req, res, next) => {
  try {
    const { token } = req.body;
    if (!token) return ApiResponse.badRequest(res, 'Token is required');

    await notificationService.removeToken(req.user.userId, token);
    return ApiResponse.success(res, null, 'FCM token removed');
  } catch (error) {
    next(error);
  }
};

// ─── PRIVACY SETTINGS ───

/**
 * PUT /users/privacy
 * Update privacy settings
 */
exports.updatePrivacy = async (req, res, next) => {
  try {
    const { lastSeen, profilePhoto, about, readReceipts } = req.body;
    const updates = {};

    if (lastSeen !== undefined) updates['privacySettings.lastSeen'] = lastSeen;
    if (profilePhoto !== undefined) updates['privacySettings.profilePhoto'] = profilePhoto;
    if (about !== undefined) updates['privacySettings.about'] = about;
    if (readReceipts !== undefined) updates['privacySettings.readReceipts'] = readReceipts;

    const user = await User.findByIdAndUpdate(
      req.user.userId,
      { $set: updates },
      { new: true, runValidators: true }
    ).select('privacySettings');

    return ApiResponse.success(res, { privacySettings: user.privacySettings }, 'Privacy updated');
  } catch (error) {
    next(error);
  }
};

/**
 * POST /users/block/:userId
 * Block a user
 */
exports.blockUser = async (req, res, next) => {
  try {
    const targetId = req.params.userId;
    if (targetId === req.user.userId) {
      return ApiResponse.badRequest(res, 'Cannot block yourself');
    }

    await User.findByIdAndUpdate(req.user.userId, {
      $addToSet: { blocked: targetId },
    });

    return ApiResponse.success(res, null, 'User blocked');
  } catch (error) {
    next(error);
  }
};

/**
 * DELETE /users/block/:userId
 * Unblock a user
 */
exports.unblockUser = async (req, res, next) => {
  try {
    const targetId = req.params.userId;
    await User.findByIdAndUpdate(req.user.userId, {
      $pull: { blocked: targetId },
    });

    return ApiResponse.success(res, null, 'User unblocked');
  } catch (error) {
    next(error);
  }
};

/**
 * GET /users/blocked
 * Get blocked users list
 */
exports.getBlockedUsers = async (req, res, next) => {
  try {
    const user = await User.findById(req.user.userId)
      .populate('blocked', 'name avatar phone')
      .select('blocked');

    return ApiResponse.success(res, { blocked: user.blocked });
  } catch (error) {
    next(error);
  }
};

/**
 * GET /users/block/:userId/status
 * Check if a specific user is blocked by current user or has blocked current user
 */
exports.checkBlockStatus = async (req, res, next) => {
  try {
    const targetId = req.params.userId;
    const currentUserId = req.user.userId;

    // Check if current user blocked target
    const currentUser = await User.findById(currentUserId).select('blocked').lean();
    const blockedByMe = (currentUser?.blocked || []).map(b => b.toString()).includes(targetId);

    // Check if target blocked current user
    const targetUser = await User.findById(targetId).select('blocked').lean();
    const blockedByThem = (targetUser?.blocked || []).map(b => b.toString()).includes(currentUserId);

    return ApiResponse.success(res, { blockedByMe, blockedByThem });
  } catch (error) {
    next(error);
  }
};

/**
 * GET /users/media
 * Get all media messages (images, videos) from all chats the user is a part of
 */
exports.getAllMedia = async (req, res, next) => {
  try {
    const userId = req.user.userId;
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 30;
    const skip = (page - 1) * limit;

    // 1. Find all chats the user is a participant of
    const { Chat, Message } = require('../models');
    const chats = await Chat.find({ participants: userId }).select('_id').lean();
    const chatIds = chats.map(c => c._id);

    // 2. Find all media messages in those chats
    const query = {
      chatId: { $in: chatIds },
      type: { $in: ['image', 'video'] },
      deletedFor: { $ne: userId },
      deletedForEveryone: { $ne: true }
    };

    const total = await Message.countDocuments(query);
    const messages = await Message.find(query)
      .populate('senderId', 'name avatar')
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limit)
      .lean();

    return ApiResponse.success(res, {
      media: messages,
      total,
      page,
      hasMore: skip + messages.length < total
    });
  } catch (error) {
    next(error);
  }
};

/**
 * DELETE /users/media
 * Delete multiple media messages for the user locally
 */
exports.deleteBulkMedia = async (req, res, next) => {
  try {
    const userId = req.user.userId;
    const { messageIds } = req.body;

    if (!messageIds || !messageIds.length) {
      return ApiResponse.badRequest(res, 'No message IDs provided for deletion');
    }

    const { Message } = require('../models');

    // Add userId to deletedFor for all provided messageIds
    await Message.updateMany(
      { _id: { $in: messageIds } },
      { $addToSet: { deletedFor: userId } }
    );

    return ApiResponse.success(res, null, 'Media deleted successfully');
  } catch (error) {
    next(error);
  }
};
