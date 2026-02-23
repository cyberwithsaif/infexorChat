const { User, Chat, Message, Group, GroupMember, Report, Broadcast } = require('../models');
const ApiResponse = require('../utils/apiResponse');
const notificationService = require('../services/notificationService');

// ─── DASHBOARD ───

/**
 * GET /admin/dashboard/stats
 * Dashboard statistics
 */
exports.getDashboardStats = async (req, res, next) => {
    try {
        const now = new Date();
        const todayStart = new Date(now.setHours(0, 0, 0, 0));
        const weekAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
        const monthAgo = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);

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
        ] = await Promise.all([
            User.countDocuments(),
            User.countDocuments({ lastSeen: { $gte: todayStart } }),
            User.countDocuments({ lastSeen: { $gte: weekAgo } }),
            User.countDocuments({ lastSeen: { $gte: monthAgo } }),
            Message.countDocuments(),
            Group.countDocuments(),
            Chat.countDocuments(),
            User.countDocuments({ isOnline: true }),
            Report.countDocuments({ status: 'pending' }),
        ]);

        // Messages per day for last 7 days
        const messagesPerDay = await Message.aggregate([
            { $match: { createdAt: { $gte: weekAgo } } },
            {
                $group: {
                    _id: { $dateToString: { format: '%Y-%m-%d', date: '$createdAt' } },
                    count: { $sum: 1 },
                },
            },
            { $sort: { _id: 1 } },
        ]);

        // New users per day for last 7 days
        const newUsersPerDay = await User.aggregate([
            { $match: { createdAt: { $gte: weekAgo } } },
            {
                $group: {
                    _id: { $dateToString: { format: '%Y-%m-%d', date: '$createdAt' } },
                    count: { $sum: 1 },
                },
            },
            { $sort: { _id: 1 } },
        ]);

        return ApiResponse.success(res, {
            totalUsers,
            activeToday,
            activeWeek,
            activeMonth,
            totalMessages,
            totalGroups,
            totalChats,
            onlineNow,
            pendingReports,
            messagesPerDay,
            newUsersPerDay,
        });
    } catch (error) {
        next(error);
    }
};

// ─── USER MANAGEMENT ───

/**
 * GET /admin/users
 * Paginated user list with search
 */
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
                .select('name phone avatar status isOnline lastSeen createdAt')
                .sort({ createdAt: -1 })
                .skip(skip)
                .limit(limit)
                .lean(),
            User.countDocuments(filter),
        ]);

        return ApiResponse.success(res, {
            users,
            pagination: {
                page,
                limit,
                total,
                pages: Math.ceil(total / limit),
            },
        });
    } catch (error) {
        next(error);
    }
};

/**
 * GET /admin/users/:id
 * User detail view
 */
exports.getUserDetail = async (req, res, next) => {
    try {
        const user = await User.findById(req.params.id)
            .select('-fcmTokens -phoneHash')
            .lean();

        if (!user) return ApiResponse.notFound(res, 'User not found');

        const [messageCount, chatCount, groupCount] = await Promise.all([
            Message.countDocuments({ senderId: user._id }),
            Chat.countDocuments({ participants: user._id }),
            GroupMember.countDocuments({ userId: user._id }),
        ]);

        return ApiResponse.success(res, {
            user,
            stats: { messageCount, chatCount, groupCount },
        });
    } catch (error) {
        next(error);
    }
};

/**
 * PUT /admin/users/:id/status
 * Change user status (active, suspended, banned)
 */
exports.changeUserStatus = async (req, res, next) => {
    try {
        const { status } = req.body;
        if (!['active', 'suspended', 'banned'].includes(status)) {
            return ApiResponse.badRequest(res, 'Invalid status');
        }

        const user = await User.findByIdAndUpdate(
            req.params.id,
            { status },
            { new: true }
        ).select('name phone status');

        if (!user) return ApiResponse.notFound(res, 'User not found');

        return ApiResponse.success(res, { user }, `User ${status}`);
    } catch (error) {
        next(error);
    }
};

/**
 * POST /admin/users/:id/force-logout
 * Force logout user (clear FCM tokens)
 */
exports.forceLogout = async (req, res, next) => {
    try {
        await User.findByIdAndUpdate(req.params.id, {
            $set: { fcmTokens: [], isOnline: false },
        });

        return ApiResponse.success(res, null, 'User force logged out');
    } catch (error) {
        next(error);
    }
};

// ─── REPORTS ───

/**
 * GET /admin/reports
 * Paginated reports list
 */
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
                .sort({ createdAt: -1 })
                .skip(skip)
                .limit(limit)
                .lean(),
            Report.countDocuments(filter),
        ]);

        return ApiResponse.success(res, {
            reports,
            pagination: { page, limit, total, pages: Math.ceil(total / limit) },
        });
    } catch (error) {
        next(error);
    }
};

/**
 * PUT /admin/reports/:id
 * Resolve a report
 */
exports.resolveReport = async (req, res, next) => {
    try {
        const { status, action } = req.body;
        if (!['reviewed', 'resolved', 'dismissed'].includes(status)) {
            return ApiResponse.badRequest(res, 'Invalid status');
        }

        const report = await Report.findByIdAndUpdate(
            req.params.id,
            { status, action: action || '', resolvedAt: new Date() },
            { new: true }
        );

        if (!report) return ApiResponse.notFound(res, 'Report not found');

        return ApiResponse.success(res, { report }, `Report ${status}`);
    } catch (error) {
        next(error);
    }
};

// ─── BROADCASTS ───

/**
 * POST /admin/broadcasts
 * Create and send a broadcast notification
 */
exports.sendBroadcast = async (req, res, next) => {
    try {
        const { title, content, segment } = req.body;

        if (!title || !content) {
            return ApiResponse.badRequest(res, 'Title and content are required');
        }

        // Build user filter based on segment
        const filter = { status: 'active' };
        if (segment === 'active_week') {
            filter.lastSeen = { $gte: new Date(Date.now() - 7 * 24 * 60 * 60 * 1000) };
        } else if (segment === 'active_month') {
            filter.lastSeen = { $gte: new Date(Date.now() - 30 * 24 * 60 * 60 * 1000) };
        }

        const users = await User.find(filter)
            .select('_id fcmTokens')
            .lean();

        // Save broadcast record
        const broadcast = await Broadcast.create({
            title,
            content,
            segment: segment || 'all',
            sentBy: req.admin._id,
            sentAt: new Date(),
            recipientCount: users.length,
            status: 'sent',
        });

        // Send push notifications (fire and forget)
        for (const user of users) {
            notificationService.sendToUser(
                user._id.toString(),
                title,
                content,
                { type: 'broadcast', broadcastId: broadcast._id.toString() }
            );
        }

        return ApiResponse.success(res, { broadcast }, 'Broadcast sent');
    } catch (error) {
        next(error);
    }
};

/**
 * GET /admin/broadcasts
 * List past broadcasts
 */
exports.getBroadcasts = async (req, res, next) => {
    try {
        const page = parseInt(req.query.page) || 1;
        const limit = parseInt(req.query.limit) || 20;
        const skip = (page - 1) * limit;

        const [broadcasts, total] = await Promise.all([
            Broadcast.find()
                .sort({ createdAt: -1 })
                .skip(skip)
                .limit(limit)
                .lean(),
            Broadcast.countDocuments(),
        ]);

        return ApiResponse.success(res, {
            broadcasts,
            pagination: { page, limit, total, pages: Math.ceil(total / limit) },
        });
    } catch (error) {
        next(error);
    }
};
