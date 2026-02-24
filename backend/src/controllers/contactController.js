const { Contact, User } = require('../models');
const ApiResponse = require('../utils/apiResponse');
const logger = require('../utils/logger');

/**
 * POST /contacts/sync
 * Accept hashed phone numbers, match with registered users
 */
exports.syncContacts = async (req, res, next) => {
  try {
    const userId = req.user.userId;
    const { contacts } = req.body;

    if (!Array.isArray(contacts) || contacts.length === 0) {
      return ApiResponse.badRequest(res, 'Contacts array is required');
    }

    // Limit batch size
    if (contacts.length > 5000) {
      return ApiResponse.badRequest(res, 'Maximum 5000 contacts per sync');
    }

    const hashes = contacts.map((c) => c.phoneHash);
    const names = {};
    contacts.forEach((c) => {
      names[c.phoneHash] = c.name || '';
    });

    // Find registered users matching these hashes
    const registeredUsers = await User.find({
      phoneHash: { $in: hashes },
      status: 'active',
    }).select('_id phone phoneHash name avatar about');

    const registeredHashSet = new Set(registeredUsers.map((u) => u.phoneHash));

    // Build bulk operations
    const bulkOps = contacts.map((c) => {
      const matchedUser = registeredUsers.find((u) => u.phoneHash === c.phoneHash);
      return {
        updateOne: {
          filter: { userId, phoneHash: c.phoneHash },
          update: {
            $set: {
              userId,
              phone: c.phone || '',
              phoneHash: c.phoneHash,
              name: c.name || '',
              isRegistered: registeredHashSet.has(c.phoneHash),
              contactUserId: matchedUser ? matchedUser._id : null,
            },
          },
          upsert: true,
        },
      };
    });

    if (bulkOps.length > 0) {
      await Contact.bulkWrite(bulkOps, { ordered: false });
    }

    // Return matched (registered) contacts with profile info
    const matchedContacts = registeredUsers
      .filter((u) => u._id.toString() !== userId) // exclude self
      .map((u) => ({
        _id: u._id,
        phone: u.phone,
        name: names[u.phoneHash] || u.name,
        serverName: u.name,
        avatar: u.avatar,
        about: u.about,
        isRegistered: true,
      }));

    logger.info(`Contact sync: ${userId} synced ${contacts.length}, matched ${matchedContacts.length}`);

    return ApiResponse.success(res, {
      synced: contacts.length,
      matched: matchedContacts.length,
      contacts: matchedContacts,
    }, 'Contacts synced');
  } catch (error) {
    next(error);
  }
};

/**
 * GET /contacts
 * Get user's synced contacts (registered only)
 */
exports.getContacts = async (req, res, next) => {
  try {
    const userId = req.user.userId;
    const { all } = req.query; // ?all=true to include non-registered

    const filter = { userId };
    if (all !== 'true') {
      filter.isRegistered = true;
    }

    const contacts = await Contact.find(filter)
      .populate('contactUserId', 'name avatar about isOnline lastSeen')
      .sort({ name: 1 })
      .lean();

    const result = contacts.map((c) => ({
      _id: c._id,
      name: c.name,
      phone: c.phone,
      isRegistered: c.isRegistered,
      contactUserId: c.contactUserId?._id || null,
      serverName: c.contactUserId?.name || '',
      avatar: c.contactUserId?.avatar || '',
      about: c.contactUserId?.about || '',
      isOnline: c.contactUserId?.isOnline || false,
      lastSeen: c.contactUserId?.lastSeen || null,
    }));

    return ApiResponse.success(res, { contacts: result });
  } catch (error) {
    next(error);
  }
};
