const Status = require('../models/Status');
const Contact = require('../models/Contact');
const User = require('../models/User');
const ApiResponse = require('../utils/apiResponse');

/**
 * POST /status
 * Create a new status (text or image)
 */
exports.createStatus = async (req, res, next) => {
    try {
        const { type, content, backgroundColor, media } = req.body;

        if (!type || !['text', 'image'].includes(type)) {
            return ApiResponse.badRequest(res, 'Type must be "text" or "image"');
        }

        if (type === 'text' && (!content || !content.trim())) {
            return ApiResponse.badRequest(res, 'Text content is required');
        }

        if (type === 'image' && (!media || !media.url)) {
            return ApiResponse.badRequest(res, 'Image URL is required');
        }

        const status = await Status.create({
            userId: req.user.userId,
            type,
            content: content || '',
            backgroundColor: backgroundColor || '#075E54',
            media: type === 'image' ? media : {},
            expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000), // 24 hours
        });

        // Populate user info for the response
        await status.populate('userId', 'name avatar phone');

        // Emit real-time event via socket (if io is available on req.app)
        const io = req.app.get('io');
        if (io) {
            io.emit('status:new', {
                status: status.toObject(),
            });
        }

        return ApiResponse.success(res, { status }, 'Status created');
    } catch (error) {
        next(error);
    }
};

/**
 * GET /status/mine
 * Get current user's own statuses
 */
exports.getMyStatuses = async (req, res, next) => {
    try {
        const statuses = await Status.find({
            userId: req.user.userId,
            expiresAt: { $gt: new Date() },
        })
            .populate('userId', 'name avatar phone')
            .populate('viewers.userId', 'name avatar')
            .sort({ createdAt: -1 });

        return ApiResponse.success(res, { statuses });
    } catch (error) {
        next(error);
    }
};

/**
 * GET /status/contacts
 * Get all contacts' unexpired statuses, grouped by user
 */
exports.getContactStatuses = async (req, res, next) => {
    try {
        // Get user's synced contacts (only registered/saved ones)
        const contacts = await Contact.find({
            userId: req.user.userId,
            isRegistered: true,
            contactUserId: { $ne: null },
        }).lean();
        const myContactUserIds = contacts
            .map((c) => c.contactUserId)
            .filter(Boolean);

        // Filter for mutual contacts: who out of my contacts also has ME saved?
        const mutualContacts = await Contact.find({
            userId: { $in: myContactUserIds },
            contactUserId: req.user.userId,
        }).lean();

        const mutualContactUserIds = mutualContacts.map((c) => c.userId);

        // Find all unexpired statuses from mutual contacts
        const statuses = await Status.find({
            userId: { $in: mutualContactUserIds },
            expiresAt: { $gt: new Date() },
        })
            .populate('userId', 'name avatar phone')
            .sort({ createdAt: -1 });

        // Group by user
        const grouped = {};
        for (const status of statuses) {
            const uid = status.userId._id.toString();
            if (!grouped[uid]) {
                grouped[uid] = {
                    user: status.userId,
                    statuses: [],
                    hasUnviewed: false,
                };
            }
            grouped[uid].statuses.push(status);

            // Check if current user has viewed this status
            const viewed = status.viewers.some(
                (v) => v.userId?.toString() === req.user.userId
            );
            if (!viewed) {
                grouped[uid].hasUnviewed = true;
            }
        }

        // Convert to array sorted by most recent
        const result = Object.values(grouped).sort((a, b) => {
            // Unviewed first, then by most recent
            if (a.hasUnviewed !== b.hasUnviewed) return a.hasUnviewed ? -1 : 1;
            const aTime = a.statuses[0]?.createdAt || 0;
            const bTime = b.statuses[0]?.createdAt || 0;
            return new Date(bTime) - new Date(aTime);
        });

        return ApiResponse.success(res, { contactStatuses: result });
    } catch (error) {
        next(error);
    }
};

/**
 * POST /status/:id/view
 * Mark a status as viewed
 */
exports.viewStatus = async (req, res, next) => {
    try {
        const status = await Status.findById(req.params.id);
        if (!status) {
            return ApiResponse.notFound(res, 'Status not found');
        }

        // Don't add viewer if it's the user's own status
        if (status.userId.toString() === req.user.userId) {
            return ApiResponse.success(res, null, 'Own status');
        }

        // Don't add duplicate viewers
        const alreadyViewed = status.viewers.some(
            (v) => v.userId?.toString() === req.user.userId
        );

        if (!alreadyViewed) {
            status.viewers.push({
                userId: req.user.userId,
                viewedAt: new Date(),
            });
            await status.save();
        }

        return ApiResponse.success(res, null, 'Status viewed');
    } catch (error) {
        next(error);
    }
};

/**
 * DELETE /status/:id
 * Delete own status
 */
exports.deleteStatus = async (req, res, next) => {
    try {
        const status = await Status.findOneAndDelete({
            _id: req.params.id,
            userId: req.user.userId,
        });

        if (!status) {
            return ApiResponse.notFound(res, 'Status not found');
        }

        // Emit real-time deletion event
        const io = req.app.get('io');
        if (io) {
            io.emit('status:deleted', {
                statusId: req.params.id,
                userId: req.user.userId,
            });
        }

        return ApiResponse.success(res, null, 'Status deleted');
    } catch (error) {
        next(error);
    }
};
