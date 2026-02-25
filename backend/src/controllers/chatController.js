const { Chat, Message, User } = require('../models');
const ApiResponse = require('../utils/apiResponse');

/**
 * POST /chats/create
 * Create or get existing 1:1 chat
 */
exports.createChat = async (req, res, next) => {
  try {
    const userId = req.user.userId;
    const { participantId } = req.body;

    if (!participantId) {
      return ApiResponse.badRequest(res, 'participantId is required');
    }

    if (participantId === userId) {
      return ApiResponse.badRequest(res, 'Cannot create chat with yourself');
    }

    // Check participant exists
    const participant = await User.findById(participantId);
    if (!participant) {
      return ApiResponse.notFound(res, 'User not found');
    }

    // Check if chat already exists
    let chat = await Chat.findOne({
      type: 'private',
      participants: { $all: [userId, participantId], $size: 2 },
    }).populate('lastMessage');

    if (chat) {
      return ApiResponse.success(res, { chat }, 'Chat already exists');
    }

    // Create new chat
    chat = await Chat.create({
      type: 'private',
      participants: [userId, participantId],
      createdBy: userId,
      lastMessageAt: new Date(),
    });

    return ApiResponse.created(res, { chat }, 'Chat created');
  } catch (error) {
    next(error);
  }
};

/**
 * GET /chats
 * List user's chats (paginated, sorted by last message)
 */
exports.getChats = async (req, res, next) => {
  try {
    const userId = req.user.userId;
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 30;
    const skip = (page - 1) * limit;

    const chats = await Chat.find({
      participants: userId,
    })
      .populate('participants', 'name avatar isOnline lastSeen phone')
      .populate('groupId', 'name avatar description memberCount')
      .populate('lastMessage')
      .lean();

    // Sort pinned chats to top, then by last message time
    chats.sort((a, b) => {
      const aPinned = a.pinnedBy?.some(p => p.toString() === userId) ? 1 : 0;
      const bPinned = b.pinnedBy?.some(p => p.toString() === userId) ? 1 : 0;
      if (aPinned !== bPinned) return bPinned - aPinned;

      const aTime = a.lastMessageAt || a.updatedAt || 0;
      const bTime = b.lastMessageAt || b.updatedAt || 0;
      return new Date(bTime) - new Date(aTime);
    });

    // Pagination after sort
    const paginatedChats = chats.slice(skip, skip + limit);

    // Batch unread count — single aggregate instead of N+1 queries
    const chatIds = paginatedChats.map((c) => c._id);
    const unreadAgg = await Message.aggregate([
      {
        $match: {
          chatId: { $in: chatIds },
          senderId: { $ne: require('mongoose').Types.ObjectId.createFromHexString(userId) },
          'readBy.userId': { $ne: require('mongoose').Types.ObjectId.createFromHexString(userId) },
          deletedFor: { $ne: require('mongoose').Types.ObjectId.createFromHexString(userId) },
        },
      },
      { $group: { _id: '$chatId', count: { $sum: 1 } } },
    ]);

    const unreadMap = {};
    unreadAgg.forEach((item) => {
      unreadMap[item._id.toString()] = item.count;
    });

    const chatsWithUnreadAndState = paginatedChats.map((chat) => {
      const isPinned = chat.pinnedBy?.some(p => p.toString() === userId) || false;
      const isMuted = chat.mutedBy?.some(m => m.userId?.toString() === userId) || false;
      const isArchived = chat.archivedBy?.some(p => p.toString() === userId) || false;
      const isMarkedUnread = chat.markedUnreadBy?.some(p => p.toString() === userId) || false;

      let actualUnreadCount = unreadMap[chat._id.toString()] || 0;
      if (isMarkedUnread && actualUnreadCount === 0) {
        actualUnreadCount = 1; // force at least 1 indicator if marked unread
      }

      return {
        ...chat,
        isPinned,
        isMuted,
        isArchived,
        isMarkedUnread,
        unreadCount: actualUnreadCount,
      };
    });

    return ApiResponse.success(res, { chats: chatsWithUnreadAndState });
  } catch (error) {
    next(error);
  }
};

/**
 * GET /chats/:chatId/messages
 * Get messages for a chat (cursor-based pagination)
 */
exports.getMessages = async (req, res, next) => {
  try {
    const userId = req.user.userId;
    const { chatId } = req.params;
    const { before, limit: queryLimit } = req.query;
    const limit = parseInt(queryLimit) || 50;

    // Verify user is participant
    const chat = await Chat.findOne({
      _id: chatId,
      participants: userId,
    });

    if (!chat) {
      return ApiResponse.notFound(res, 'Chat not found');
    }

    const query = {
      chatId,
      deletedFor: { $ne: userId },
    };

    // Cursor-based: get messages before this ID
    if (before) {
      query._id = { $lt: before };
    }

    const messages = await Message.find(query)
      .populate('senderId', 'name avatar')
      .populate('replyTo', 'content type senderId')
      .sort({ createdAt: -1 })
      .limit(limit)
      .lean();

    return ApiResponse.success(res, {
      messages: messages.reverse(),
      hasMore: messages.length === limit,
    });
  } catch (error) {
    next(error);
  }
};

/**
 * GET /chats/:chatId/media
 * Get media messages for a chat (images, videos, audio, documents)
 */
exports.getChatMedia = async (req, res, next) => {
  try {
    const userId = req.user.userId;
    const { chatId } = req.params;
    const { type, page: queryPage, limit: queryLimit } = req.query;
    const page = parseInt(queryPage) || 1;
    const limit = parseInt(queryLimit) || 30;
    const skip = (page - 1) * limit;

    // Verify user is participant
    const chat = await Chat.findOne({ _id: chatId, participants: userId });
    if (!chat) {
      return ApiResponse.notFound(res, 'Chat not found');
    }

    // Build type filter
    let typeFilter;
    if (type === 'media') {
      typeFilter = { $in: ['image', 'video'] };
    } else if (type === 'docs') {
      typeFilter = 'document';
    } else if (type === 'audio') {
      typeFilter = { $in: ['audio', 'voice'] };
    } else {
      typeFilter = { $in: ['image', 'video', 'audio', 'voice', 'document'] };
    }

    const query = {
      chatId,
      type: typeFilter,
      deletedFor: { $ne: userId },
      deletedForEveryone: { $ne: true },
    };

    const total = await Message.countDocuments(query);
    const messages = await Message.find(query)
      .populate('senderId', 'name avatar')
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limit)
      .lean();

    return ApiResponse.success(res, {
      messages,
      total,
      page,
      hasMore: skip + messages.length < total,
    });
  } catch (error) {
    next(error);
  }
};

/**
 * POST /chats/:chatId/pin
 * Toggle pin/unpin chat for the current user
 */
exports.pinChat = async (req, res, next) => {
  try {
    const userId = req.user.userId;
    const { chatId } = req.params;

    const chat = await Chat.findOne({ _id: chatId, participants: userId });
    if (!chat) return ApiResponse.notFound(res, 'Chat not found');

    const isPinned = chat.pinnedBy.some(id => id.toString() === userId);
    if (isPinned) {
      chat.pinnedBy.pull(userId);
    } else {
      chat.pinnedBy.addToSet(userId);
    }
    await chat.save();

    return ApiResponse.success(res, { pinned: !isPinned }, isPinned ? 'Chat unpinned' : 'Chat pinned');
  } catch (error) {
    next(error);
  }
};

/**
 * POST /chats/:chatId/mute
 * Toggle mute for the current user
 */
exports.muteChat = async (req, res, next) => {
  try {
    const userId = req.user.userId;
    const { chatId } = req.params;

    const chat = await Chat.findOne({ _id: chatId, participants: userId });
    if (!chat) return ApiResponse.notFound(res, 'Chat not found');

    const muteIndex = chat.mutedBy.findIndex(m => m.userId?.toString() === userId);
    if (muteIndex >= 0) {
      chat.mutedBy.splice(muteIndex, 1);
    } else {
      chat.mutedBy.push({ userId, until: null });
    }
    await chat.save();

    return ApiResponse.success(res, { muted: muteIndex < 0 }, muteIndex >= 0 ? 'Chat unmuted' : 'Chat muted');
  } catch (error) {
    next(error);
  }
};

/**
 * POST /chats/:chatId/archive
 * Toggle archive for the current user
 */
exports.archiveChat = async (req, res, next) => {
  try {
    const userId = req.user.userId;
    const { chatId } = req.params;

    const chat = await Chat.findOne({ _id: chatId, participants: userId });
    if (!chat) return ApiResponse.notFound(res, 'Chat not found');

    const isArchived = chat.archivedBy.some(id => id.toString() === userId);
    if (isArchived) {
      chat.archivedBy.pull(userId);
    } else {
      chat.archivedBy.addToSet(userId);
    }
    await chat.save();

    return ApiResponse.success(res, { archived: !isArchived }, isArchived ? 'Chat unarchived' : 'Chat archived');
  } catch (error) {
    next(error);
  }
};

/**
 * POST /chats/:chatId/mark-read
 * Mark chat as read
 */
exports.markAsRead = async (req, res, next) => {
  try {
    const userId = req.user.userId;
    const { chatId } = req.params;

    const chat = await Chat.findOne({ _id: chatId, participants: userId });
    if (!chat) return ApiResponse.notFound(res, 'Chat not found');

    chat.markedUnreadBy.pull(userId);
    await chat.save();

    // Mark messages as read as well
    const Message = require('../models/Message');
    await Message.updateMany(
      {
        chatId,
        senderId: { $ne: userId },
        'readBy.userId': { $ne: userId },
      },
      {
        $push: { readBy: { userId, readAt: new Date() } }
      }
    );

    return ApiResponse.success(res, { markedRead: true }, 'Chat marked as read');
  } catch (error) {
    next(error);
  }
};

/**
 * POST /chats/:chatId/mark-unread
 * Mark chat as unread
 */
exports.markAsUnread = async (req, res, next) => {
  try {
    const userId = req.user.userId;
    const { chatId } = req.params;

    const chat = await Chat.findOne({ _id: chatId, participants: userId });
    if (!chat) return ApiResponse.notFound(res, 'Chat not found');

    chat.markedUnreadBy.addToSet(userId);
    await chat.save();

    return ApiResponse.success(res, { markedUnread: true }, 'Chat marked as unread');
  } catch (error) {
    next(error);
  }
};

/**
 * DELETE /chats/:chatId
 * Delete chat for the current user (remove from participants)
 */
exports.deleteChat = async (req, res, next) => {
  try {
    const userId = req.user.userId;
    const { chatId } = req.params;

    const chat = await Chat.findOne({ _id: chatId, participants: userId });
    if (!chat) return ApiResponse.notFound(res, 'Chat not found');

    // Remove user from participants
    chat.participants.pull(userId);

    // If no participants left, delete the chat entirely
    if (chat.participants.length === 0) {
      await Chat.findByIdAndDelete(chatId);
    } else {
      await chat.save();
    }

    return ApiResponse.success(res, null, 'Chat deleted');
  } catch (error) {
    next(error);
  }
};
