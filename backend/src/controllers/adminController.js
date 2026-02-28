const { User, Chat, Message, Call } = require('../models');
const Admin = require('../models/Admin');
const Report = require('../models/Report');
const Broadcast = require('../models/Broadcast');
const GroupMember = require('../models/GroupMember');
const Device = require('../models/Device');
const { getRedis } = require('../config/redis');
const { getIO } = require('../config/socket');
const { collectMetrics, collectStorageMetrics, collectPm2Metrics, getTurnStats, getRedisMetrics } = require('../services/metricsCollector');
const notificationService = require('../services/notificationService');
const ApiResponse = require('../utils/apiResponse');
const logger = require('../utils/logger');
const path = require('path');
const fs = require('fs');
const { broadcastQueue } = require('../config/queue');
const audienceService = require('../services/audienceService');

// ─────────────────────────────────────
// SECTION 1 — DASHBOARD OVERVIEW
// ─────────────────────────────────────

exports.getDashboardStats = async (req, res, next) => {
    try {
        const now = new Date();
        const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
        const weekAgo = new Date(now - 7 * 86400000);
        const monthAgo = new Date(now - 30 * 86400000);

        let io;
        try { io = getIO(); } catch (_) { }

        // Active sockets across all workers
        let connectedSockets = 0;
        if (io) {
            try {
                const sockets = await io.fetchSockets();
                connectedSockets = sockets.length;
            } catch {
                connectedSockets = io.engine?.clientsCount || 0;
            }
        }

        // Parallel queries
        const [
            totalUsers,
            activeToday,
            activeWeek,
            activeMonth,
            totalMessages,
            totalGroups,
            totalChats,
            onlineNow,
            pendingReports,
            messagesToday,
            activeCalls,
            activeAudioCalls,
            activeVideoCalls,
            callsToday,
            messagesPerDay,
            newUsersPerDay,
        ] = await Promise.all([
            User.countDocuments(),
            User.countDocuments({ lastSeen: { $gte: today } }),
            User.countDocuments({ lastSeen: { $gte: weekAgo } }),
            User.countDocuments({ lastSeen: { $gte: monthAgo } }),
            Message.countDocuments(),
            Chat.countDocuments({ type: 'group' }),
            Chat.countDocuments(),
            User.countDocuments({ isOnline: true }),
            Report.countDocuments({ status: 'pending' }).catch(() => 0),
            Message.countDocuments({ createdAt: { $gte: today } }),
            Call.countDocuments({ status: { $in: ['ringing', 'accepted'] } }),
            Call.countDocuments({ status: { $in: ['ringing', 'accepted'] }, type: 'audio' }),
            Call.countDocuments({ status: { $in: ['ringing', 'accepted'] }, type: 'video' }),
            Call.countDocuments({ createdAt: { $gte: today } }),
            Message.aggregate([
                { $match: { createdAt: { $gte: weekAgo } } },
                { $group: { _id: { $dateToString: { format: '%Y-%m-%d', date: '$createdAt' } }, count: { $sum: 1 } } },
                { $sort: { _id: 1 } },
            ]),
            User.aggregate([
                { $match: { createdAt: { $gte: monthAgo } } },
                { $group: { _id: { $dateToString: { format: '%Y-%m-%d', date: '$createdAt' } }, count: { $sum: 1 } } },
                { $sort: { _id: 1 } },
            ]),
        ]);

        // System metrics
        const systemMetrics = await collectMetrics();
        const redisMetrics = await getRedisMetrics();

        return ApiResponse.success(res, {
            totalUsers,
            activeToday,
            activeWeek,
            activeMonth,
            totalMessages,
            totalGroups,
            totalChats,
            onlineNow,
            connectedSockets,
            pendingReports,
            messagesToday,
            activeCalls,
            activeAudioCalls,
            activeVideoCalls,
            callsToday,
            messagesPerDay,
            newUsersPerDay,
            system: systemMetrics,
            redis: redisMetrics,
        });
    } catch (error) {
        next(error);
    }
};

/**
 * GET /admin/dashboard/live
 * Lightweight live metrics endpoint (called every 3-5s)
 */
exports.getLiveMetrics = async (req, res, next) => {
    try {
        let io;
        try { io = getIO(); } catch (_) { }

        let connectedSockets = 0;
        if (io) {
            try {
                const sockets = await io.fetchSockets();
                connectedSockets = sockets.length;
            } catch {
                connectedSockets = io.engine?.clientsCount || 0;
            }
        }

        const systemMetrics = await collectMetrics();
        const redisMetrics = await getRedisMetrics();
        const activeCalls = await Call.countDocuments({ status: { $in: ['ringing', 'accepted'] } });
        const activeAudioCalls = await Call.countDocuments({ status: { $in: ['ringing', 'accepted'] }, type: 'audio' });
        const activeVideoCalls = await Call.countDocuments({ status: { $in: ['ringing', 'accepted'] }, type: 'video' });

        return ApiResponse.success(res, {
            connectedSockets,
            activeCalls,
            activeAudioCalls,
            activeVideoCalls,
            system: systemMetrics,
            redis: redisMetrics,
        });
    } catch (error) {
        next(error);
    }
};

// ─────────────────────────────────────
// SECTION 2 — USER MANAGEMENT
// ─────────────────────────────────────

exports.getUsers = async (req, res, next) => {
    try {
        const page = parseInt(req.query.page) || 1;
        const limit = parseInt(req.query.limit) || 20;
        const search = req.query.search || '';
        const status = req.query.status || '';
        const skip = (page - 1) * limit;

        const filter = {};
        if (search) {
            filter.$or = [
                { name: { $regex: search, $options: 'i' } },
                { phone: { $regex: search, $options: 'i' } },
            ];
        }
        if (status) filter.status = status;

        const [users, total] = await Promise.all([
            User.find(filter)
                .select('name phone avatar status isOnline lastSeen createdAt fcmToken voipToken')
                .sort({ createdAt: -1 })
                .skip(skip)
                .limit(limit)
                .lean(),
            User.countDocuments(filter),
        ]);

        return ApiResponse.success(res, {
            users,
            pagination: { page, limit, total, pages: Math.ceil(total / limit) },
        });
    } catch (error) {
        next(error);
    }
};

exports.getUserDetail = async (req, res, next) => {
    try {
        const user = await User.findById(req.params.id).lean();
        if (!user) return ApiResponse.notFound(res, 'User not found');

        const [messageCount, chatCount, groupCount, callHistory, devices] = await Promise.all([
            Message.countDocuments({ senderId: user._id }),
            Chat.countDocuments({ participants: user._id }),
            GroupMember.countDocuments({ userId: user._id }),
            Call.find({ $or: [{ callerId: user._id }, { receiverId: user._id }] })
                .sort({ createdAt: -1 })
                .limit(20)
                .lean(),
            Device.find({ userId: user._id }).lean().catch(() => []),
        ]);

        return ApiResponse.success(res, {
            user,
            stats: { messageCount, chatCount, groupCount },
            callHistory,
            devices,
        });
    } catch (error) {
        next(error);
    }
};

exports.changeUserStatus = async (req, res, next) => {
    try {
        const { status } = req.body;
        if (!['active', 'suspended', 'banned'].includes(status)) {
            return ApiResponse.badRequest(res, 'Invalid status');
        }
        const user = await User.findByIdAndUpdate(req.params.id, { status }, { new: true })
            .select('name phone status');
        if (!user) return ApiResponse.notFound(res, 'User not found');
        return ApiResponse.success(res, { user }, `User ${status}`);
    } catch (error) {
        next(error);
    }
};

exports.forceLogout = async (req, res, next) => {
    try {
        const userId = req.params.id;

        // 1. Clear user tokens and mark offline
        await User.findByIdAndUpdate(userId, {
            $set: { fcmToken: '', voipToken: '', isOnline: false },
        });

        // 2. Invalidate all device refresh tokens so re-auth is impossible
        const Device = require('../models/Device');
        await Device.updateMany(
            { userId },
            { $set: { refreshToken: '' } }
        );

        // 3. Emit force-logout event to all connected sockets BEFORE disconnecting
        //    This tells the Flutter app to clear local auth state and navigate to login
        try {
            const io = getIO();
            io.to(`user:${userId}`).emit('force-logout', {
                reason: 'Admin forced logout',
            });

            // Give the event a moment to be delivered, then disconnect
            setTimeout(async () => {
                try {
                    const sockets = await io.in(`user:${userId}`).fetchSockets();
                    sockets.forEach(s => s.disconnect(true));
                } catch { }
            }, 500);
        } catch { }

        return ApiResponse.success(res, null, 'User force logged out');
    } catch (error) {
        next(error);
    }
};

exports.deleteUser = async (req, res, next) => {
    try {
        const userId = req.params.id;
        const user = await User.findById(userId);
        if (!user) return ApiResponse.notFound(res, 'User not found');

        // Disconnect sockets first
        try {
            const io = getIO();
            const sockets = await io.in(`user:${userId}`).fetchSockets();
            sockets.forEach(s => s.disconnect(true));
        } catch { }

        await User.findByIdAndDelete(userId);
        logger.info(`[Admin] User ${userId} deleted by admin ${req.admin.adminId}`);
        return ApiResponse.success(res, null, 'User deleted');
    } catch (error) {
        next(error);
    }
};

exports.resetUserRateLimit = async (req, res, next) => {
    try {
        const redis = getRedis();
        if (!redis) return ApiResponse.badRequest(res, 'Redis not available');
        const userId = req.params.id;
        await redis.del(`call:rate:${userId}`);
        return ApiResponse.success(res, null, 'Rate limit reset');
    } catch (error) {
        next(error);
    }
};

// ─────────────────────────────────────
// SECTION 3 — CALL ANALYTICS
// ─────────────────────────────────────

exports.getActiveCalls = async (req, res, next) => {
    try {
        const calls = await Call.find({ status: { $in: ['ringing', 'accepted'] } })
            .populate('callerId', 'name phone avatar')
            .populate('receiverId', 'name phone avatar')
            .sort({ createdAt: -1 })
            .lean();

        // Add duration to accepted calls
        calls.forEach(c => {
            if (c.status === 'accepted' && c.answeredAt) {
                c.liveDuration = Math.round((Date.now() - new Date(c.answeredAt).getTime()) / 1000);
            }
        });

        return ApiResponse.success(res, { calls });
    } catch (error) {
        next(error);
    }
};

exports.getCallAnalytics = async (req, res, next) => {
    try {
        const today = new Date(); today.setHours(0, 0, 0, 0);
        const weekAgo = new Date(Date.now() - 7 * 86400000);

        const [
            totalCalls,
            callsToday,
            completedCalls,
            missedCalls,
            declinedCalls,
            cancelledCalls,
            failedCalls,
            avgDuration,
            callsPerDay,
            busyRejections,
        ] = await Promise.all([
            Call.countDocuments(),
            Call.countDocuments({ createdAt: { $gte: today } }),
            Call.countDocuments({ status: 'completed' }),
            Call.countDocuments({ status: 'missed' }),
            Call.countDocuments({ status: 'declined' }),
            Call.countDocuments({ status: 'cancelled' }),
            Call.countDocuments({ status: 'failed' }).catch(() => 0),
            Call.aggregate([
                { $match: { status: 'completed', duration: { $gt: 0 } } },
                { $group: { _id: null, avg: { $avg: '$duration' } } },
            ]).then(r => Math.round(r[0]?.avg || 0)),
            Call.aggregate([
                { $match: { createdAt: { $gte: weekAgo } } },
                { $group: { _id: { $dateToString: { format: '%Y-%m-%d', date: '$createdAt' } }, count: { $sum: 1 } } },
                { $sort: { _id: 1 } },
            ]),
            Call.countDocuments({ status: 'busy' }).catch(() => 0),
        ]);

        const dropRate = totalCalls > 0
            ? ((missedCalls + cancelledCalls + (failedCalls || 0)) / totalCalls * 100).toFixed(1)
            : '0.0';

        return ApiResponse.success(res, {
            totalCalls,
            callsToday,
            completedCalls,
            missedCalls,
            declinedCalls,
            cancelledCalls,
            failedCalls,
            avgDuration,
            dropRate,
            busyRejections,
            callsPerDay,
        });
    } catch (error) {
        next(error);
    }
};

exports.forceEndCall = async (req, res, next) => {
    try {
        const callId = req.params.id;
        const call = await Call.findByIdAndUpdate(callId, {
            status: 'completed',
            endedAt: new Date(),
        }, { new: true });

        if (!call) return ApiResponse.notFound(res, 'Call not found');

        // Release Redis locks
        const redis = getRedis();
        if (redis) {
            await redis.del(`call:active:${call.callerId}`).catch(() => { });
            await redis.del(`call:active:${call.receiverId}`).catch(() => { });
        }

        // Notify participants
        try {
            const io = getIO();
            io.to(`user:${call.callerId}`).emit('call:ended', { chatId: call.chatId, endedBy: 'admin' });
            io.to(`user:${call.receiverId}`).emit('call:ended', { chatId: call.chatId, endedBy: 'admin' });
        } catch { }

        logger.info(`[Admin] Force-ended call ${callId}`);
        return ApiResponse.success(res, { call }, 'Call force-ended');
    } catch (error) {
        next(error);
    }
};

// ─────────────────────────────────────
// SECTION 4 — CHAT ANALYTICS
// ─────────────────────────────────────

exports.getChatAnalytics = async (req, res, next) => {
    try {
        const today = new Date(); today.setHours(0, 0, 0, 0);
        const hourAgo = new Date(Date.now() - 3600000);

        const [messagesToday, messagesLastHour, totalChats, topChats] = await Promise.all([
            Message.countDocuments({ createdAt: { $gte: today } }),
            Message.countDocuments({ createdAt: { $gte: hourAgo } }),
            Chat.countDocuments(),
            Chat.find()
                .sort({ lastMessageAt: -1 })
                .limit(10)
                .populate('participants', 'name avatar')
                .select('participants lastMessageAt type')
                .lean(),
        ]);

        const messagesPerSecond = (messagesLastHour / 3600).toFixed(2);

        return ApiResponse.success(res, {
            messagesToday,
            messagesLastHour,
            messagesPerSecond,
            totalChats,
            topChats,
        });
    } catch (error) {
        next(error);
    }
};

// ─────────────────────────────────────
// SECTION 5 — SERVER STATUS
// ─────────────────────────────────────

exports.getServerStatus = async (req, res, next) => {
    try {
        const [systemMetrics, redisMetrics, pm2Processes] = await Promise.all([
            collectMetrics(),
            getRedisMetrics(),
            collectPm2Metrics(),
        ]);

        let io;
        try { io = getIO(); } catch (_) { }
        let connectedSockets = 0;
        if (io) {
            try {
                const sockets = await io.fetchSockets();
                connectedSockets = sockets.length;
            } catch { connectedSockets = io.engine?.clientsCount || 0; }
        }

        const mongoose = require('mongoose');
        const mongoStatus = {
            readyState: mongoose.connection.readyState,
            connections: {
                current: mongoose.connections.length,
            },
        };

        try {
            const serverStatus = await mongoose.connection.db.admin().serverStatus();
            mongoStatus.connections = serverStatus.connections;
            mongoStatus.opcounters = serverStatus.opcounters;
            mongoStatus.uptime = serverStatus.uptime;
        } catch { }

        return ApiResponse.success(res, {
            system: systemMetrics,
            redis: redisMetrics,
            pm2: pm2Processes,
            mongodb: mongoStatus,
            sockets: { connected: connectedSockets },
        });
    } catch (error) {
        next(error);
    }
};

// ─────────────────────────────────────
// SECTION 6 — STORAGE & MEDIA
// ─────────────────────────────────────

exports.getStorageStats = async (req, res, next) => {
    try {
        const storage = await collectStorageMetrics();
        return ApiResponse.success(res, storage);
    } catch (error) {
        next(error);
    }
};

exports.browseMedia = async (req, res, next) => {
    try {
        const uploadsBase = path.resolve('/var/www/whatsapplikeapp/uploads');
        const subPath = req.query.path || '';
        const filter = req.query.filter || ''; // image, video, audio
        const search = req.query.search || '';
        const page = parseInt(req.query.page) || 1;
        const limit = parseInt(req.query.limit) || 50;

        // Security: prevent path traversal
        const targetPath = path.resolve(uploadsBase, subPath);
        if (!targetPath.startsWith(uploadsBase)) {
            return ApiResponse.forbidden(res, 'Access denied: path traversal detected');
        }

        if (!fs.existsSync(targetPath)) {
            return ApiResponse.notFound(res, 'Directory not found');
        }

        const entries = fs.readdirSync(targetPath, { withFileTypes: true });
        let items = entries.map(entry => {
            const fullPath = path.join(targetPath, entry.name);
            const relativePath = path.relative(uploadsBase, fullPath);
            let stat = null;
            try { stat = fs.statSync(fullPath); } catch { }

            const ext = path.extname(entry.name).toLowerCase();
            let mediaType = 'other';
            if (['.jpg', '.jpeg', '.png', '.gif', '.webp', '.svg'].includes(ext)) mediaType = 'image';
            else if (['.mp4', '.mov', '.avi', '.mkv', '.webm'].includes(ext)) mediaType = 'video';
            else if (['.mp3', '.wav', '.ogg', '.aac', '.m4a', '.opus'].includes(ext)) mediaType = 'audio';

            return {
                name: entry.name,
                isDirectory: entry.isDirectory(),
                path: relativePath,
                size: stat?.size || 0,
                sizeMB: stat ? (stat.size / 1048576).toFixed(2) : '0',
                modified: stat?.mtime || null,
                created: stat?.birthtime || null,
                mediaType,
                ext,
                url: `/uploads/${relativePath.replace(/\\/g, '/')}`,
            };
        });

        // Apply filters
        if (filter) items = items.filter(i => i.mediaType === filter || i.isDirectory);
        if (search) items = items.filter(i => i.name.toLowerCase().includes(search.toLowerCase()));

        // Sort: dirs first, then by modified desc
        items.sort((a, b) => {
            if (a.isDirectory !== b.isDirectory) return a.isDirectory ? -1 : 1;
            return (b.modified?.getTime() || 0) - (a.modified?.getTime() || 0);
        });

        const total = items.length;
        const paginated = items.slice((page - 1) * limit, page * limit);

        return ApiResponse.success(res, {
            items: paginated,
            currentPath: subPath || '/',
            pagination: { page, limit, total, pages: Math.ceil(total / limit) },
        });
    } catch (error) {
        next(error);
    }
};

exports.deleteMedia = async (req, res, next) => {
    try {
        const uploadsBase = path.resolve('/var/www/whatsapplikeapp/uploads');
        const filePath = req.body.path;
        if (!filePath) return ApiResponse.badRequest(res, 'Path is required');

        const fullPath = path.resolve(uploadsBase, filePath);
        if (!fullPath.startsWith(uploadsBase)) {
            return ApiResponse.forbidden(res, 'Access denied');
        }
        if (!fs.existsSync(fullPath)) {
            return ApiResponse.notFound(res, 'File not found');
        }

        const stat = fs.statSync(fullPath);
        if (stat.isDirectory()) {
            return ApiResponse.badRequest(res, 'Cannot delete directories');
        }

        fs.unlinkSync(fullPath);
        logger.info(`[Admin] Deleted media: ${filePath} by admin ${req.admin.adminId}`);
        return ApiResponse.success(res, null, 'File deleted');
    } catch (error) {
        next(error);
    }
};

// ─────────────────────────────────────
// SECTION 7 — TURN MONITORING
// ─────────────────────────────────────

exports.getTurnStatus = async (req, res, next) => {
    try {
        const turnStats = getTurnStats();
        return ApiResponse.success(res, turnStats);
    } catch (error) {
        next(error);
    }
};

// ─────────────────────────────────────
// SECTION 8 — SECURITY
// ─────────────────────────────────────

exports.getSecurityEvents = async (req, res, next) => {
    try {
        const redis = getRedis();
        const events = [];

        // Get rate limit triggers from Redis
        if (redis) {
            try {
                const rateLimitKeys = await redis.keys('call:rate:*');
                for (const key of rateLimitKeys.slice(0, 50)) {
                    const count = await redis.get(key);
                    const userId = key.replace('call:rate:', '');
                    if (parseInt(count) > 3) {
                        events.push({ type: 'rate_limit', userId, count: parseInt(count), key });
                    }
                }
            } catch { }
        }

        return ApiResponse.success(res, { events });
    } catch (error) {
        next(error);
    }
};

// ─────────────────────────────────────
// SECTION 9 — ALERTS (config stored in Redis)
// ─────────────────────────────────────

exports.getAlertConfig = async (req, res, next) => {
    try {
        const redis = getRedis();
        const defaults = {
            cpuThreshold: 80,
            ramThreshold: 85,
            diskThreshold: 85,
            redisLatencyThreshold: 5,
            callDropThreshold: 5,
            telegramBotToken: '',
            telegramChatId: '',
            slackWebhook: '',
            alertEmail: '',
            enabled: false,
        };

        if (redis) {
            try {
                const config = await redis.get('admin:alerts:config');
                if (config) return ApiResponse.success(res, JSON.parse(config));
            } catch { }
        }

        return ApiResponse.success(res, defaults);
    } catch (error) {
        next(error);
    }
};

exports.updateAlertConfig = async (req, res, next) => {
    try {
        const redis = getRedis();
        if (!redis) return ApiResponse.badRequest(res, 'Redis not available');
        await redis.set('admin:alerts:config', JSON.stringify(req.body));
        return ApiResponse.success(res, req.body, 'Alert config updated');
    } catch (error) {
        next(error);
    }
};

// ─────────────────────────────────────
// REPORTS & BROADCASTS (kept from original)
// ─────────────────────────────────────

exports.getReports = async (req, res, next) => {
    try {
        const page = parseInt(req.query.page) || 1;
        const limit = parseInt(req.query.limit) || 20;
        const status = req.query.status || '';
        const skip = (page - 1) * limit;
        const filter = {};
        if (status) filter.status = status;

        const [reports, total] = await Promise.all([
            Report.find(filter)
                .populate('reporterId', 'name phone avatar')
                .sort({ createdAt: -1 }).skip(skip).limit(limit).lean(),
            Report.countDocuments(filter),
        ]);
        return ApiResponse.success(res, { reports, pagination: { page, limit, total, pages: Math.ceil(total / limit) } });
    } catch (error) { next(error); }
};

exports.resolveReport = async (req, res, next) => {
    try {
        const { status, action } = req.body;
        if (!['reviewed', 'resolved', 'dismissed'].includes(status)) {
            return ApiResponse.badRequest(res, 'Invalid status');
        }
        const report = await Report.findByIdAndUpdate(req.params.id, {
            status, action: action || '', resolvedAt: new Date(),
        }, { new: true });
        if (!report) return ApiResponse.notFound(res, 'Report not found');
        return ApiResponse.success(res, { report }, `Report ${status}`);
    } catch (error) { next(error); }
};

exports.sendBroadcast = async (req, res, next) => {
    try {
        const { title, message, segment = 'all', platform = 'both', link = '' } = req.body;
        if (!title || !message) return ApiResponse.badRequest(res, 'Title and message required');

        // Redis distributed lock to prevent duplicate concurrent broadcasts
        const redis = getRedis();
        if (redis) {
            const lock = await redis.setnx('lock:broadcast:create', '1');
            if (!lock) return ApiResponse.badRequest(res, 'A broadcast is already being processed');
            await redis.expire('lock:broadcast:create', 5);
        }

        const totalRecipients = await audienceService.countRecipients(segment, platform);

        const broadcast = await Broadcast.create({
            title,
            message,
            segment,
            platform,
            link: link.trim(),
            createdBy: req.admin.adminId || req.admin._id,
            totalRecipients,
            status: 'queued',
        });

        await broadcastQueue.add('send-broadcast', { broadcastId: broadcast._id });

        return ApiResponse.success(res, { broadcast }, 'Broadcast dispatched to queue');
    } catch (error) { next(error); }
};

exports.getBroadcasts = async (req, res, next) => {
    try {
        const page = parseInt(req.query.page) || 1;
        const limit = parseInt(req.query.limit) || 20;
        const skip = (page - 1) * limit;
        const [broadcasts, total] = await Promise.all([
            Broadcast.find().populate('createdBy', 'username name').sort({ createdAt: -1 }).skip(skip).limit(limit).lean(),
            Broadcast.countDocuments(),
        ]);
        return ApiResponse.success(res, { broadcasts, pagination: { page, limit, total, totalPages: Math.ceil(total / limit) } });
    } catch (error) { next(error); }
};

exports.getBroadcastStats = async (req, res, next) => {
    try {
        const queueSize = await broadcastQueue.getWaitingCount();
        const activeCount = await broadcastQueue.getActiveCount();
        const stats = await Broadcast.aggregate([
            { $match: { status: 'sent' } },
            {
                $group: {
                    _id: null,
                    totalSuccess: { $sum: '$successCount' },
                    totalFailure: { $sum: '$failureCount' },
                }
            }
        ]);

        const sum = stats[0] || { totalSuccess: 0, totalFailure: 0 };
        const totalSent = sum.totalSuccess + sum.totalFailure;

        return ApiResponse.success(res, {
            queueSize,
            activeCount,
            totalSuccess: sum.totalSuccess,
            totalFailure: sum.totalFailure,
            successRate: totalSent > 0 ? (sum.totalSuccess / totalSent) * 100 : 0
        });
    } catch (error) { next(error); }
};
