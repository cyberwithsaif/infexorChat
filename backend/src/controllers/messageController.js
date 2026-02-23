const { Message, Chat } = require('../models');
const { getIO } = require('../config/socket');
const ApiResponse = require('../utils/apiResponse');

/**
 * DELETE /chats/:chatId/messages/:messageId
 * Delete message (for me or for everyone)
 */
exports.deleteMessage = async (req, res, next) => {
  try {
    const userId = req.user.userId;
    const { chatId, messageId } = req.params;
    const { forEveryone } = req.body;

    const message = await Message.findOne({ _id: messageId, chatId });
    if (!message) {
      return ApiResponse.notFound(res, 'Message not found');
    }

    if (forEveryone) {
      // Only sender can delete for everyone
      if (message.senderId.toString() !== userId) {
        return ApiResponse.forbidden(res, 'Only the sender can delete for everyone');
      }
      message.deletedForEveryone = true;
      message.content = '';
      message.media = {};
      message.type = 'revoked';
      await message.save();

      // Notify via socket
      try {
        const io = getIO();
        const chat = await Chat.findById(chatId);
        chat?.participants.forEach((pid) => {
          io.to(`user:${pid}`).emit('message:deleted', {
            chatId,
            messageId,
            forEveryone: true,
          });
        });
      } catch { /* socket not init */ }
    } else {
      await Message.findByIdAndUpdate(messageId, {
        $addToSet: { deletedFor: userId },
      });
    }

    return ApiResponse.success(res, null, 'Message deleted');
  } catch (error) {
    next(error);
  }
};

/**
 * POST /chats/:chatId/messages/:messageId/react
 * Add/remove reaction
 */
exports.reactToMessage = async (req, res, next) => {
  try {
    const userId = req.user.userId;
    const { chatId, messageId } = req.params;
    const { emoji } = req.body;

    if (!emoji) {
      return ApiResponse.badRequest(res, 'Emoji is required');
    }

    const message = await Message.findOne({ _id: messageId, chatId });
    if (!message) {
      return ApiResponse.notFound(res, 'Message not found');
    }

    // Remove existing reaction from this user
    message.reactions = message.reactions.filter(
      (r) => r.userId.toString() !== userId
    );

    // Add new reaction
    message.reactions.push({ userId, emoji, createdAt: new Date() });
    await message.save();

    // Notify via socket
    try {
      const io = getIO();
      const chat = await Chat.findById(chatId);
      chat?.participants.forEach((pid) => {
        io.to(`user:${pid}`).emit('message:reaction', {
          chatId,
          messageId,
          userId,
          emoji,
        });
      });
    } catch { /* socket not init */ }

    return ApiResponse.success(res, null, 'Reaction added');
  } catch (error) {
    next(error);
  }
};

/**
 * POST /chats/:chatId/messages/:messageId/star
 * Toggle star on a message
 */
exports.starMessage = async (req, res, next) => {
  try {
    const userId = req.user.userId;
    const { messageId } = req.params;

    const message = await Message.findById(messageId);
    if (!message) {
      return ApiResponse.notFound(res, 'Message not found');
    }

    const isStarred = message.starredBy.some((id) => id.toString() === userId);

    if (isStarred) {
      await Message.findByIdAndUpdate(messageId, {
        $pull: { starredBy: userId },
      });
    } else {
      await Message.findByIdAndUpdate(messageId, {
        $addToSet: { starredBy: userId },
      });
    }

    return ApiResponse.success(
      res,
      { starred: !isStarred },
      isStarred ? 'Message unstarred' : 'Message starred'
    );
  } catch (error) {
    next(error);
  }
};

/**
 * GET /chats/starred
 * Get all starred messages for user
 */
exports.getStarredMessages = async (req, res, next) => {
  try {
    const userId = req.user.userId;

    const messages = await Message.find({
      starredBy: userId,
      deletedFor: { $ne: userId },
      deletedForEveryone: { $ne: true },
    })
      .populate('senderId', 'name avatar')
      .populate('chatId', 'type participants')
      .sort({ createdAt: -1 })
      .limit(100)
      .lean();

    return ApiResponse.success(res, { messages });
  } catch (error) {
    next(error);
  }
};

/**
 * POST /chats/:chatId/messages/:messageId/forward
 * Forward a message to another chat
 */
exports.forwardMessage = async (req, res, next) => {
  try {
    const userId = req.user.userId;
    const { messageId } = req.params;
    const { targetChatId } = req.body;

    if (!targetChatId) {
      return ApiResponse.badRequest(res, 'targetChatId is required');
    }

    // Verify user is in target chat
    const targetChat = await Chat.findOne({
      _id: targetChatId,
      participants: userId,
    });
    if (!targetChat) {
      return ApiResponse.notFound(res, 'Target chat not found');
    }

    const original = await Message.findById(messageId);
    if (!original) {
      return ApiResponse.notFound(res, 'Message not found');
    }

    const forwarded = await Message.create({
      chatId: targetChatId,
      senderId: userId,
      type: original.type,
      content: original.content,
      media: original.media,
      location: original.location,
      contactShare: original.contactShare,
      forwardedFrom: original._id,
      status: 'sent',
    });

    // Update target chat
    await Chat.findByIdAndUpdate(targetChatId, {
      lastMessage: forwarded._id,
      lastMessageAt: forwarded.createdAt,
    });

    // Notify via socket
    try {
      const io = getIO();
      const populated = await Message.findById(forwarded._id)
        .populate('senderId', 'name avatar')
        .lean();

      targetChat.participants.forEach((pid) => {
        if (pid.toString() !== userId) {
          io.to(`user:${pid}`).emit('message:new', populated);
        }
      });
    } catch { /* socket not init */ }

    return ApiResponse.success(res, { message: forwarded }, 'Message forwarded');
  } catch (error) {
    next(error);
  }
};

/**
 * GET /chats/:chatId/messages/search
 * Search messages within a chat
 */
exports.searchMessages = async (req, res, next) => {
  try {
    const userId = req.user.userId;
    const { chatId } = req.params;
    const { q } = req.query;

    if (!q || q.trim().length === 0) {
      return ApiResponse.badRequest(res, 'Search query is required');
    }

    // Verify user is in chat
    const chat = await Chat.findOne({ _id: chatId, participants: userId });
    if (!chat) {
      return ApiResponse.notFound(res, 'Chat not found');
    }

    const messages = await Message.find({
      chatId,
      content: { $regex: q, $options: 'i' },
      deletedFor: { $ne: userId },
      deletedForEveryone: { $ne: true },
    })
      .populate('senderId', 'name avatar')
      .sort({ createdAt: -1 })
      .limit(50)
      .lean();

    return ApiResponse.success(res, { messages });
  } catch (error) {
    next(error);
  }
};
