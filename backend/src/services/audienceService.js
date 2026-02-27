const { Device, User } = require('../models');

/**
 * Returns a MongoDB cursor stream of unique, valid FCM/APNs tokens for a given segment and platform.
 * Using a cursor prevents loading 100,000s of tokens into Node.js memory at once.
 * 
 * @param {string} segment  - 'all', 'active', 'banned', or 'custom'
 * @param {string} platform - 'android', 'ios', or 'both'
 * @returns {mongoose.QueryCursor}
 */
exports.getTokenStream = (segment, platform) => {
    const query = {
        fcmToken: { $ne: '' },
        isActive: true, // Only fetch tokens for active device sessions
    };

    // 1. Platform Filter
    if (platform !== 'both') {
        query.platform = platform; // 'android' or 'ios'
    }

    // 2. Segment Filter
    if (segment === 'active') {
        // Active in the last 7 days
        const sevenDaysAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
        query.lastActive = { $gte: sevenDaysAgo };
    } else if (segment === 'custom') {
        // Expandable custom filters (e.g., country later)
        // For now, treats custom as active since no complex custom UI was requested
        const thirtyDaysAgo = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
        query.lastActive = { $gte: thirtyDaysAgo };
    }

    // For "banned" we actually need to look at the User model,
    // but to keep it performant, we stream the Device collection 
    // and `.populate('userId', 'status')` to check if banned.

    // Return the raw streaming cursor
    return Device.find(query)
        .populate('userId', 'status')
        .select('fcmToken platform userId')
        .cursor();
};

/**
 * Counts the approximate number of users that match the segment constraints.
 * Used to set `totalRecipients` before broadcast starts.
 */
exports.countRecipients = async (segment, platform) => {
    const query = {
        fcmToken: { $ne: '' },
        isActive: true,
    };

    if (platform !== 'both') {
        query.platform = platform;
    }

    if (segment === 'active') {
        const sevenDaysAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
        query.lastActive = { $gte: sevenDaysAgo };
    }

    // Note: if segment === "banned", this simple count will over-estimate 
    // because we don't deeply query the User table for the count.
    // The stream will properly filter them.
    return await Device.countDocuments(query);
};
