const jwt = require('jsonwebtoken');
const axios = require('axios');
const env = require('../config/env');
const { Chat, Message, User } = require('../models');
const presenceService = require('./presenceService');
const notificationService = require('./notificationService');
const logger = require('../utils/logger');

// ─── SOCKET RATE LIMITER ───
// Prevents a single client from flooding the server with events
const socketRateLimits = new Map(); // socketId -> { count, resetAt }
const SOCKET_RATE_WINDOW = 5000;    // 5 second window
const SOCKET_RATE_MAX = 30;         // max 30 events per window

function isSocketRateLimited(socketId) {
  const now = Date.now();
  let entry = socketRateLimits.get(socketId);
  if (!entry || now > entry.resetAt) {
    entry = { count: 0, resetAt: now + SOCKET_RATE_WINDOW };
    socketRateLimits.set(socketId, entry);
  }
  entry.count++;
  return entry.count > SOCKET_RATE_MAX;
}

// Cleanup stale rate limit entries every 30s
setInterval(() => {
  const now = Date.now();
  for (const [key, entry] of socketRateLimits.entries()) {
    if (now > entry.resetAt + 10000) socketRateLimits.delete(key);
  }
}, 30000);

/**
 * Fire-and-forget webhook to n8n for AI auto-reply
 * Only triggers for non-AI text messages when AI is enabled
 */
async function triggerAIWebhook(chatId, userId, messageContent) {
  if (!env.ai.enabled) return;
  if (!env.ai.webhookUrl) return;
  if (!messageContent || messageContent.trim().length === 0) return;

  try {
    await axios.post(
      env.ai.webhookUrl,
      {
        chatId: chatId.toString(),
        userId: userId.toString(),
        message: messageContent,
      },
      {
        headers: {
          'Content-Type': 'application/json',
          'X-Webhook-Secret': env.ai.webhookSecret,
        },
        timeout: 5000,
      }
    );
    logger.info(`[AI] Webhook triggered for chat ${chatId}`);
  } catch (err) {
    logger.error(`[AI] Webhook trigger failed: ${err.message}`);
  }
}

// Map userId -> Set of socket IDs
const userSockets = new Map();

function getUserSockets(userId) {
  return userSockets.get(userId.toString()) || new Set();
}

function initSocketHandlers(io) {
  // Auth middleware
  io.use((socket, next) => {
    const token = socket.handshake.auth.token;
    if (!token) {
      return next(new Error('Authentication required'));
    }
    try {
      const decoded = jwt.verify(token, env.jwt.secret);
      socket.userId = decoded.userId;
      next();
    } catch {
      next(new Error('Invalid token'));
    }
  });

  io.on('connection', (socket) => {
    const userId = socket.userId;
    logger.info(`Socket connected: ${socket.id} (user: ${userId})`);

    // Track user socket
    if (!userSockets.has(userId)) {
      userSockets.set(userId, new Set());
    }
    userSockets.get(userId).add(socket.id);

    // Mark user online
    User.findByIdAndUpdate(userId, { isOnline: true, lastSeen: new Date() }).catch(() => { });
    presenceService.setOnline(userId).catch(() => { });

    // Broadcast online status
    io.emit('presence:online', { userId });

    // Join personal room
    socket.join(`user:${userId}`);

    // Auto-join all group chat rooms
    Chat.find({ participants: userId, type: 'group' })
      .select('_id')
      .lean()
      .then((chats) => {
        chats.forEach((chat) => {
          socket.join(`chat:${chat._id}`);
        });
      })
      .catch(() => { });

    // ─── HEARTBEAT ───
    socket.on('heartbeat', () => {
      presenceService.heartbeat(userId).catch(() => { });
    });

    // ─── RECORDING INDICATOR ───
    socket.on('recording:start', (data) => {
      const { chatId } = data;
      socket.to(`chat:${chatId}`).emit('recording:start', { chatId, userId });
    });

    socket.on('recording:stop', (data) => {
      const { chatId } = data;
      socket.to(`chat:${chatId}`).emit('recording:stop', { chatId, userId });
    });

    // ─── TYPING INDICATORS ───
    socket.on('typing:start', (data) => {
      try {
        const { chatId } = data;
        if (!chatId) return;
        // Broadcast to all other participants in this chat
        Chat.findOne({ _id: chatId, participants: userId })
          .select('participants')
          .lean()
          .then((chat) => {
            if (!chat) return;
            chat.participants.forEach((pid) => {
              const p = pid.toString();
              if (p !== userId) {
                io.to(`user:${p}`).emit('typing:start', { chatId, userId });
              }
            });
          })
          .catch(() => { });
      } catch (_) { }
    });

    socket.on('typing:stop', (data) => {
      try {
        const { chatId } = data;
        if (!chatId) return;
        Chat.findOne({ _id: chatId, participants: userId })
          .select('participants')
          .lean()
          .then((chat) => {
            if (!chat) return;
            chat.participants.forEach((pid) => {
              const p = pid.toString();
              if (p !== userId) {
                io.to(`user:${p}`).emit('typing:stop', { chatId, userId });
              }
            });
          })
          .catch(() => { });
      } catch (_) { }
    });

    // ─── SEND MESSAGE ───
    socket.on('message:send', async (data, callback) => {
      try {
        // Rate limit check
        if (isSocketRateLimited(socket.id)) {
          return callback?.({ error: 'Rate limited. Please slow down.' });
        }

        const { chatId, type, content, media, replyTo, location, contactShare } = data;

        // --- ABUSE DETECTION (SPAM) ---
        const redisClient = require('../config/redis').client;
        if (redisClient && type === 'text' && content) {
          try {
            const penaltyKey = `abuse:penalty:${userId}`;
            const isRestricted = await redisClient.get(penaltyKey);
            if (isRestricted) {
              return callback?.({ error: 'Account temporarily restricted due to anomalous activity.' });
            }

            const messageHash = require('crypto').createHash('md5').update(content).digest('hex');
            const spamKey = `abuse:spam:${userId}:${messageHash}`;
            const count = await redisClient.incr(spamKey);
            if (count === 1) await redisClient.expire(spamKey, 120); // 2 min window

            if (count > 15) {
              logger.warn(`Spam detected over Socket: User ${userId} sent identical message > 15 times`);
              await redisClient.set(penaltyKey, 'spam', 'EX', 3600); // 1 hour timeout
              return callback?.({ error: 'Account temporarily restricted due to spamming.' });
            }
          } catch (e) { logger.error('Socket abuse check error', e); }
        }
        // --- END ABUSE DETECTION ---

        // Verify user is in chat
        const chat = await Chat.findOne({ _id: chatId, participants: userId }).lean();
        if (!chat) {
          return callback?.({ error: 'Chat not found' });
        }

        // Block check: run ALL block checks in PARALLEL (was sequential before)
        const otherParticipants = chat.participants
          .map(p => p.toString())
          .filter(p => p !== userId);

        if (otherParticipants.length > 0) {
          // Fetch sender + all recipients blocked lists concurrently
          const [sender, ...recipients] = await Promise.all([
            User.findById(userId).select('blocked').lean(),
            ...otherParticipants.map(pid => User.findById(pid).select('blocked').lean())
          ]);
          const senderBlocked = (sender?.blocked || []).map(b => b.toString());

          for (let i = 0; i < otherParticipants.length; i++) {
            const pid = otherParticipants[i];
            if (senderBlocked.includes(pid)) {
              return callback?.({ error: 'blocked', message: 'You have blocked this contact' });
            }
            const recipientBlocked = (recipients[i]?.blocked || []).map(b => b.toString());
            if (recipientBlocked.includes(userId)) {
              return callback?.({ error: 'blocked', message: 'You cannot send messages to this contact' });
            }
          }
        }

        // Create message
        const message = await Message.create({
          chatId,
          senderId: userId,
          type: type || 'text',
          content: content || '',
          media: media || {},
          replyTo: replyTo || null,
          location: location || {},
          contactShare: contactShare || {},
          status: 'sent',
        });

        // Update chat lastMessage + populate sender in PARALLEL
        const [, populatedMsg] = await Promise.all([
          Chat.findByIdAndUpdate(chatId, {
            lastMessage: message._id,
            lastMessageAt: message.createdAt,
          }),
          Message.findById(message._id)
            .populate('senderId', 'name avatar')
            .populate('replyTo', 'content type senderId')
            .lean()
        ]);

        // Send to all participants + handle delivery/notifications
        const senderUser = populatedMsg.senderId;
        const senderName = senderUser?.name || 'Someone';
        let previewBody = content || '';
        if (type === 'image') previewBody = '📷 Photo';
        else if (type === 'video') previewBody = '🎥 Video';
        else if (type === 'audio') previewBody = '🎵 Audio';
        else if (type === 'document') previewBody = '📄 Document';
        else if (type === 'location') previewBody = '📍 Location';
        else if (type === 'contact') previewBody = '👤 Contact';
        else if (type === 'gif') previewBody = 'GIF';

        const isGroupChat = chat.type === 'group';
        let pushTitle = senderName;
        if (isGroupChat) {
          try {
            const Group = require('../models').Group;
            const group = await Group.findById(chat.groupId).select('name').lean();
            pushTitle = `${senderName} @ ${group?.name || 'Group'}`;
          } catch (_) { }
        }

        chat.participants.forEach((participantId) => {
          const pid = participantId.toString();
          if (pid === userId) return;

          // Emit message to recipient
          io.to(`user:${pid}`).emit('message:new', populatedMsg);

          if (getUserSockets(pid).size > 0) {
            // Online — mark as delivered (fire-and-forget)
            Message.findByIdAndUpdate(message._id, {
              status: 'delivered',
              $addToSet: { deliveredTo: { userId: pid, at: new Date() } },
            }).catch(() => { });

            io.to(`user:${userId}`).emit('message:status', {
              messageId: message._id,
              status: 'delivered',
            });
          } else {
            // Offline — push notification (fire-and-forget)
            notificationService.sendToUser(pid, pushTitle, previewBody, {
              chatId: chatId.toString(),
              messageId: message._id.toString(),
              type: 'message',
            });
          }
        });

        // Reply to sender immediately
        callback?.({ success: true, message: populatedMsg });

        // AI auto-reply (fire-and-forget, non-blocking)
        if (!data.isAI && (type === 'text' || !type) && content) {
          const { handleAutoReply } = require('./aiBotService');
          handleAutoReply(chatId, userId, content).catch((err) =>
            logger.error('[AI] Bot auto-reply error:', err)
          );
        }
      } catch (error) {
        logger.error('message:send error:', error);
        callback?.({ error: 'Failed to send message' });
      }
    });

    // ─── MESSAGE DELIVERED ───
    socket.on('message:delivered', async (data) => {
      try {
        const { messageId } = data;
        const message = await Message.findById(messageId);
        if (!message) return;

        await Message.findByIdAndUpdate(messageId, {
          status: 'delivered',
          $addToSet: { deliveredTo: { userId, at: new Date() } },
        });

        // Notify sender
        io.to(`user:${message.senderId}`).emit('message:status', {
          messageId,
          status: 'delivered',
        });
      } catch (error) {
        logger.error('message:delivered error:', error);
      }
    });

    // ─── MESSAGE READ ───
    socket.on('message:read', async (data) => {
      try {
        const { chatId } = data;

        // Mark all unread messages in chat as read
        const unread = await Message.find({
          chatId,
          senderId: { $ne: userId },
          'readBy.userId': { $ne: userId },
        });

        if (unread.length === 0) return;

        await Message.updateMany(
          {
            chatId,
            senderId: { $ne: userId },
            'readBy.userId': { $ne: userId },
          },
          {
            $addToSet: { readBy: { userId, at: new Date() } },
            $set: { status: 'read' },
          }
        );

        // Notify senders
        const senderIds = [...new Set(unread.map((m) => m.senderId?.toString()).filter(Boolean))];
        senderIds.forEach((senderId) => {
          io.to(`user:${senderId}`).emit('message:read-ack', {
            chatId,
            readBy: userId,
          });
        });
      } catch (error) {
        logger.error('message:read error:', error);
      }
    });

    // ─── TYPING ───
    socket.on('typing:start', (data) => {
      const { chatId } = data;
      socket.to(`chat:${chatId}`).emit('typing:start', { chatId, userId });
    });

    socket.on('typing:stop', (data) => {
      const { chatId } = data;
      socket.to(`chat:${chatId}`).emit('typing:stop', { chatId, userId });
    });

    // ─── JOIN CHAT ROOMS ───
    socket.on('chat:join', (data) => {
      const { chatId } = data;
      socket.join(`chat:${chatId}`);
    });

    socket.on('chat:leave', (data) => {
      const { chatId } = data;
      socket.leave(`chat:${chatId}`);
    });

    // ─── CALL SIGNALING ───

    // Caller initiates a call → notify callee
    socket.on('call:initiate', async (data) => {
      try {
        const { chatId, type, participants } = data;
        if (!chatId) return;

        // Get caller info
        const caller = await User.findById(userId).select('name avatar phone').lean();
        const callerName = caller?.name || 'Unknown';
        const callerAvatar = caller?.avatar || null;
        const callerPhone = caller?.phone || null;

        // Find chat participants to notify
        const chat = await Chat.findById(chatId).select('participants').lean();
        if (!chat) return;

        const targetIds = (participants && participants.length > 0)
          ? participants.map(p => p.toString())
          : chat.participants.map(p => p.toString()).filter(p => p !== userId);

        logger.info(`[call:initiate] ${userId} calling ${targetIds.join(',')} in chat ${chatId}, type=${type}`);

        // Emit call:incoming to each target
        targetIds.forEach(targetId => {
          io.to(`user:${targetId}`).emit('call:incoming', {
            chatId,
            callerId: userId,
            callerName,
            callerAvatar,
            callerPhone,
            type: type || 'audio',
            caller: { name: callerName, avatar: callerAvatar },
          });
        });

        // Send push notification to offline targets
        targetIds.forEach(targetId => {
          if (getUserSockets(targetId).size === 0) {
            notificationService.sendToUser(
              targetId,
              callerName,
              `Incoming ${type || 'audio'} call`,
              {
                chatId,
                type: type === 'video' ? 'video_call' : 'audio_call',
                callerId: userId,
                callerName: callerName,
                callerAvatar: callerAvatar || '',
              }
            );
          }
        });
      } catch (error) {
        logger.error('call:initiate error:', error);
      }
    });

    // Callee accepts → notify caller
    socket.on('call:accept', (data) => {
      const { chatId, callerId } = data;
      if (!chatId || !callerId) return;
      logger.info(`[call:accept] ${userId} accepted call from ${callerId} in chat ${chatId}`);
      io.to(`user:${callerId}`).emit('call:accepted', {
        chatId,
        acceptedBy: userId,
      });
    });

    // Callee rejects → notify caller and save in chat history
    socket.on('call:reject', async (data) => {
      const { chatId, callerId } = data;
      if (!chatId || !callerId) return;
      logger.info(`[call:reject] ${userId} rejected call from ${callerId} in chat ${chatId}`);
      io.to(`user:${callerId}`).emit('call:rejected', {
        chatId,
        rejectedBy: userId,
      });

      try {
        // Create system message for missed/rejected call
        const Message = require('../models/Message');
        const Chat = require('../models/Chat');

        const sysMsg = await Message.create({
          chatId,
          type: 'system',
          content: 'Missed call',
        });

        await Chat.findByIdAndUpdate(chatId, {
          lastMessage: sysMsg._id,
          lastMessageAt: sysMsg.createdAt,
        });

        // Broadcast the system message so UI updates immediately
        io.to(`chat:${chatId}`).emit('message:new', sysMsg);
      } catch (e) {
        logger.error('Error saving missed call history:', e);
      }
    });

    // Either side ends the call → notify the other and save in chat history
    socket.on('call:end', async (data) => {
      const { chatId, duration } = data; // the frontend can pass duration, but we'll default
      if (!chatId) return;
      logger.info(`[call:end] ${userId} ended call in chat ${chatId}`);

      const chat = await Chat.findById(chatId).select('participants').lean();
      if (!chat) return;

      chat.participants.forEach(pid => {
        const p = pid.toString();
        if (p !== userId) {
          io.to(`user:${p}`).emit('call:ended', { chatId, endedBy: userId });
        }
      });

      try {
        // Create system message for call history
        const Message = require('../models/Message');
        const ChatUpdate = require('../models/Chat');

        const sysMsg = await Message.create({
          chatId,
          type: 'system',
          content: 'Call ended',
        });

        await ChatUpdate.findByIdAndUpdate(chatId, {
          lastMessage: sysMsg._id,
          lastMessageAt: sysMsg.createdAt,
        });

        // Broadcast the system message
        io.to(`chat:${chatId}`).emit('message:new', sysMsg);
      } catch (e) {
        logger.error('Error saving call history:', e);
      }
    });

    socket.on('call:ended', async (data) => {
      const { chatId } = data;
      if (!chatId) return;

      const chat = await Chat.findById(chatId).select('participants').lean();
      if (!chat) return;

      chat.participants.forEach(pid => {
        const p = pid.toString();
        if (p !== userId) {
          io.to(`user:${p}`).emit('call:ended', { chatId, endedBy: userId });
        }
      });
    });

    // ─── WEBRTC P2P SIGNALING ───

    // Relay SDP offer from caller to callee
    socket.on('webrtc:offer', (data) => {
      const { chatId, targetUserId, sdp } = data;
      if (!chatId || !targetUserId || !sdp) return;
      logger.info(`[webrtc:offer] ${userId} -> ${targetUserId}`);
      io.to(`user:${targetUserId}`).emit('webrtc:offer', {
        chatId,
        fromUserId: userId,
        sdp,
      });
    });

    // Relay SDP answer from callee to caller
    socket.on('webrtc:answer', (data) => {
      const { chatId, targetUserId, sdp } = data;
      if (!chatId || !targetUserId || !sdp) return;
      logger.info(`[webrtc:answer] ${userId} -> ${targetUserId}`);
      io.to(`user:${targetUserId}`).emit('webrtc:answer', {
        chatId,
        fromUserId: userId,
        sdp,
      });
    });

    // Relay ICE candidates bidirectionally
    socket.on('webrtc:ice-candidate', (data) => {
      const { chatId, targetUserId, candidate } = data;
      if (!chatId || !targetUserId || !candidate) return;
      io.to(`user:${targetUserId}`).emit('webrtc:ice-candidate', {
        chatId,
        fromUserId: userId,
        candidate,
      });
    });

    // ─── DISCONNECT ───
    socket.on('disconnect', () => {
      logger.info(`Socket disconnected: ${socket.id} (user: ${userId})`);

      const sockets = userSockets.get(userId);
      if (sockets) {
        sockets.delete(socket.id);
        if (sockets.size === 0) {
          userSockets.delete(userId);
          // Mark user offline
          User.findByIdAndUpdate(userId, {
            isOnline: false,
            lastSeen: new Date(),
          }).catch(() => { });
          presenceService.setOffline(userId).catch(() => { });

          // Broadcast offline status
          io.emit('presence:offline', { userId });
        }
      }
    });
  });
}

module.exports = { initSocketHandlers, getUserSockets };
