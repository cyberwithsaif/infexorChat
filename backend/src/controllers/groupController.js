const { Group, GroupMember, Chat, Message, User } = require('../models');
const ApiResponse = require('../utils/apiResponse');
const crypto = require('crypto');

// ─── HELPERS ───

/**
 * Create a system message in a group chat
 */
async function systemMessage(chatId, content) {
    const msg = await Message.create({
        chatId,
        senderId: null,
        type: 'system',
        content,
        status: 'sent',
    });
    return msg;
}

/**
 * Check if user has admin-level role in group
 */
async function isAdmin(groupId, userId) {
    const member = await GroupMember.findOne({
        groupId,
        userId,
        isActive: true,
        role: { $in: ['superadmin', 'admin'] },
    });
    return !!member;
}

/**
 * Check if user is superadmin
 */
async function isSuperAdmin(groupId, userId) {
    const member = await GroupMember.findOne({
        groupId,
        userId,
        isActive: true,
        role: 'superadmin',
    });
    return !!member;
}

// ─── CONTROLLERS ───

/**
 * POST /groups/create
 * Create a new group
 */
exports.createGroup = async (req, res, next) => {
    try {
        const userId = req.user.userId;
        const { name, description, avatar, memberIds } = req.body;

        if (!name || !name.trim()) {
            return ApiResponse.badRequest(res, 'Group name is required');
        }

        if (!memberIds || !Array.isArray(memberIds) || memberIds.length === 0) {
            return ApiResponse.badRequest(res, 'At least one member is required');
        }

        // Ensure creator is not in memberIds
        const uniqueMembers = [...new Set(memberIds.filter((id) => id !== userId))];

        // Verify all members exist
        const users = await User.find({ _id: { $in: uniqueMembers } }).select('_id name');
        if (users.length !== uniqueMembers.length) {
            return ApiResponse.badRequest(res, 'One or more members not found');
        }

        // All participants = creator + members
        const allParticipants = [userId, ...uniqueMembers];

        // Create group
        const group = await Group.create({
            name: name.trim(),
            description: description || '',
            avatar: avatar || '',
            createdBy: userId,
            memberCount: allParticipants.length,
        });

        // Create chat linked to group
        const chat = await Chat.create({
            type: 'group',
            participants: allParticipants,
            groupId: group._id,
            createdBy: userId,
        });

        // Link chat to group
        group.chatId = chat._id;
        await group.save();

        // Create GroupMember entries
        const memberDocs = allParticipants.map((uid) => ({
            groupId: group._id,
            userId: uid,
            role: uid === userId ? 'superadmin' : 'member',
            addedBy: userId,
        }));
        await GroupMember.insertMany(memberDocs);

        // System messages
        const creator = await User.findById(userId).select('name');
        const creatorName = creator?.name || 'Someone';
        await systemMessage(chat._id, `${creatorName} created this group`);

        const addedNames = users.map((u) => u.name).join(', ');
        if (addedNames) {
            await systemMessage(chat._id, `${creatorName} added ${addedNames}`);
        }

        const populatedGroup = await Group.findById(group._id).populate('createdBy', 'name avatar');

        return ApiResponse.created(res, { group: populatedGroup, chatId: chat._id }, 'Group created');
    } catch (error) {
        next(error);
    }
};

/**
 * GET /groups/:groupId
 * Get group info with members
 */
exports.getGroupInfo = async (req, res, next) => {
    try {
        const userId = req.user.userId;
        const { groupId } = req.params;

        const group = await Group.findById(groupId).populate('createdBy', 'name avatar');
        if (!group) {
            return ApiResponse.notFound(res, 'Group not found');
        }

        // Verify user is a member
        const membership = await GroupMember.findOne({ groupId, userId, isActive: true });
        if (!membership) {
            return ApiResponse.forbidden(res, 'You are not a member of this group');
        }

        const members = await GroupMember.find({ groupId, isActive: true })
            .populate('userId', 'name avatar phone isOnline lastSeen')
            .sort({ role: 1, joinedAt: 1 })
            .lean();

        return ApiResponse.success(res, {
            group,
            members,
            myRole: membership.role,
            isMuted: membership.mutedUntil ? new Date(membership.mutedUntil) > new Date() : false,
        });
    } catch (error) {
        next(error);
    }
};

/**
 * PUT /groups/:groupId
 * Update group info (name, description, avatar)
 */
exports.updateGroup = async (req, res, next) => {
    try {
        const userId = req.user.userId;
        const { groupId } = req.params;
        const { name, description, avatar } = req.body;

        const group = await Group.findById(groupId);
        if (!group) {
            return ApiResponse.notFound(res, 'Group not found');
        }

        // Check permission
        if (group.settings.onlyAdminsCanEditInfo) {
            const admin = await isAdmin(groupId, userId);
            if (!admin) {
                return ApiResponse.forbidden(res, 'Only admins can edit group info');
            }
        } else {
            const member = await GroupMember.findOne({ groupId, userId, isActive: true });
            if (!member) {
                return ApiResponse.forbidden(res, 'You are not a member of this group');
            }
        }

        const updates = {};
        if (name !== undefined) updates.name = name.trim();
        if (description !== undefined) updates.description = description;
        if (avatar !== undefined) updates.avatar = avatar;

        const updated = await Group.findByIdAndUpdate(groupId, updates, { new: true })
            .populate('createdBy', 'name avatar');

        // System message
        const user = await User.findById(userId).select('name');
        if (name) {
            await systemMessage(group.chatId, `${user?.name} changed the group name to "${name.trim()}"`);
        }

        return ApiResponse.success(res, { group: updated }, 'Group updated');
    } catch (error) {
        next(error);
    }
};

/**
 * POST /groups/:groupId/members
 * Add members to group
 */
exports.addMembers = async (req, res, next) => {
    try {
        const userId = req.user.userId;
        const { groupId } = req.params;
        const { memberIds } = req.body;

        if (!memberIds || !Array.isArray(memberIds) || memberIds.length === 0) {
            return ApiResponse.badRequest(res, 'memberIds array is required');
        }

        const group = await Group.findById(groupId);
        if (!group || !group.isActive) {
            return ApiResponse.notFound(res, 'Group not found');
        }

        // Only admins can add
        const admin = await isAdmin(groupId, userId);
        if (!admin) {
            return ApiResponse.forbidden(res, 'Only admins can add members');
        }

        // Check max members
        const currentCount = await GroupMember.countDocuments({ groupId, isActive: true });
        if (currentCount + memberIds.length > group.maxMembers) {
            return ApiResponse.badRequest(res, `Group can have at most ${group.maxMembers} members`);
        }

        // Verify users exist
        const users = await User.find({ _id: { $in: memberIds } }).select('_id name');
        const validIds = users.map((u) => u._id.toString());

        const added = [];
        for (const memberId of validIds) {
            // Check if already member
            const existing = await GroupMember.findOne({ groupId, userId: memberId });
            if (existing) {
                if (!existing.isActive) {
                    existing.isActive = true;
                    existing.role = 'member';
                    existing.addedBy = userId;
                    existing.joinedAt = new Date();
                    await existing.save();
                    added.push(memberId);
                }
                continue;
            }

            await GroupMember.create({
                groupId,
                userId: memberId,
                role: 'member',
                addedBy: userId,
            });
            added.push(memberId);
        }

        if (added.length > 0) {
            // Update chat participants
            await Chat.findByIdAndUpdate(group.chatId, {
                $addToSet: { participants: { $each: added } },
            });

            // Update member count
            const newCount = await GroupMember.countDocuments({ groupId, isActive: true });
            await Group.findByIdAndUpdate(groupId, { memberCount: newCount });

            // System message
            const adder = await User.findById(userId).select('name');
            const addedUsers = users.filter((u) => added.includes(u._id.toString()));
            const names = addedUsers.map((u) => u.name).join(', ');
            await systemMessage(group.chatId, `${adder?.name} added ${names}`);
        }

        return ApiResponse.success(res, { added }, 'Members added');
    } catch (error) {
        next(error);
    }
};

/**
 * DELETE /groups/:groupId/members/:memberId
 * Remove a member from group
 */
exports.removeMember = async (req, res, next) => {
    try {
        const userId = req.user.userId;
        const { groupId, memberId } = req.params;

        const group = await Group.findById(groupId);
        if (!group || !group.isActive) {
            return ApiResponse.notFound(res, 'Group not found');
        }

        // Can't remove yourself (use leave instead)
        if (memberId === userId) {
            return ApiResponse.badRequest(res, 'Use the leave endpoint to leave the group');
        }

        // Only admins can remove
        const adminCheck = await isAdmin(groupId, userId);
        if (!adminCheck) {
            return ApiResponse.forbidden(res, 'Only admins can remove members');
        }

        // Superadmin can't be removed by a regular admin
        const targetMember = await GroupMember.findOne({ groupId, userId: memberId, isActive: true });
        if (!targetMember) {
            return ApiResponse.notFound(res, 'Member not found in group');
        }

        if (targetMember.role === 'superadmin') {
            return ApiResponse.forbidden(res, 'Cannot remove the group creator');
        }

        // If target is admin, only superadmin can remove
        if (targetMember.role === 'admin') {
            const superCheck = await isSuperAdmin(groupId, userId);
            if (!superCheck) {
                return ApiResponse.forbidden(res, 'Only the group creator can remove admins');
            }
        }

        targetMember.isActive = false;
        await targetMember.save();

        // Remove from chat participants
        await Chat.findByIdAndUpdate(group.chatId, {
            $pull: { participants: memberId },
        });

        // Update count
        const newCount = await GroupMember.countDocuments({ groupId, isActive: true });
        await Group.findByIdAndUpdate(groupId, { memberCount: newCount });

        // System message
        const remover = await User.findById(userId).select('name');
        const removed = await User.findById(memberId).select('name');
        await systemMessage(group.chatId, `${remover?.name} removed ${removed?.name}`);

        return ApiResponse.success(res, null, 'Member removed');
    } catch (error) {
        next(error);
    }
};

/**
 * PUT /groups/:groupId/members/:memberId/role
 * Change member role
 */
exports.changeRole = async (req, res, next) => {
    try {
        const userId = req.user.userId;
        const { groupId, memberId } = req.params;
        const { role } = req.body;

        if (!role || !['admin', 'member'].includes(role)) {
            return ApiResponse.badRequest(res, 'Role must be "admin" or "member"');
        }

        // Only superadmin can change roles
        const superCheck = await isSuperAdmin(groupId, userId);
        if (!superCheck) {
            return ApiResponse.forbidden(res, 'Only the group creator can change roles');
        }

        const target = await GroupMember.findOne({ groupId, userId: memberId, isActive: true });
        if (!target) {
            return ApiResponse.notFound(res, 'Member not found');
        }

        if (target.role === 'superadmin') {
            return ApiResponse.forbidden(res, 'Cannot change creator role');
        }

        target.role = role;
        await target.save();

        // System message
        const changer = await User.findById(userId).select('name');
        const changed = await User.findById(memberId).select('name');
        const group = await Group.findById(groupId);
        const action = role === 'admin' ? 'made admin' : 'removed as admin';
        await systemMessage(group.chatId, `${changer?.name} ${action} ${changed?.name}`);

        return ApiResponse.success(res, { role }, 'Role updated');
    } catch (error) {
        next(error);
    }
};

/**
 * POST /groups/:groupId/invite-link
 * Generate / regenerate invite link
 */
exports.generateInviteLink = async (req, res, next) => {
    try {
        const userId = req.user.userId;
        const { groupId } = req.params;

        const adminCheck = await isAdmin(groupId, userId);
        if (!adminCheck) {
            return ApiResponse.forbidden(res, 'Only admins can manage invite links');
        }

        const inviteLink = crypto.randomBytes(16).toString('hex');
        const group = await Group.findByIdAndUpdate(
            groupId,
            { inviteLink, inviteLinkEnabled: true },
            { new: true }
        );

        return ApiResponse.success(res, { inviteLink: group.inviteLink }, 'Invite link generated');
    } catch (error) {
        next(error);
    }
};

/**
 * PUT /groups/:groupId/invite-link
 * Toggle invite link on/off
 */
exports.toggleInviteLink = async (req, res, next) => {
    try {
        const userId = req.user.userId;
        const { groupId } = req.params;
        const { enabled } = req.body;

        const adminCheck = await isAdmin(groupId, userId);
        if (!adminCheck) {
            return ApiResponse.forbidden(res, 'Only admins can manage invite links');
        }

        const group = await Group.findByIdAndUpdate(
            groupId,
            { inviteLinkEnabled: !!enabled },
            { new: true }
        );

        return ApiResponse.success(res, { inviteLinkEnabled: group.inviteLinkEnabled });
    } catch (error) {
        next(error);
    }
};

/**
 * POST /groups/join/:inviteLink
 * Join group via invite link
 */
exports.joinViaLink = async (req, res, next) => {
    try {
        const userId = req.user.userId;
        const { inviteLink } = req.params;

        const group = await Group.findOne({ inviteLink, isActive: true });
        if (!group) {
            return ApiResponse.notFound(res, 'Invalid or expired invite link');
        }

        if (!group.inviteLinkEnabled) {
            return ApiResponse.badRequest(res, 'Invite link is disabled');
        }

        // Check if already member
        const existing = await GroupMember.findOne({ groupId: group._id, userId });
        if (existing && existing.isActive) {
            return ApiResponse.success(res, { chatId: group.chatId }, 'Already a member');
        }

        // Check max members
        const count = await GroupMember.countDocuments({ groupId: group._id, isActive: true });
        if (count >= group.maxMembers) {
            return ApiResponse.badRequest(res, 'Group is full');
        }

        // Add or reactivate
        if (existing) {
            existing.isActive = true;
            existing.role = 'member';
            existing.joinedAt = new Date();
            await existing.save();
        } else {
            await GroupMember.create({
                groupId: group._id,
                userId,
                role: 'member',
            });
        }

        // Update chat + count
        await Chat.findByIdAndUpdate(group.chatId, {
            $addToSet: { participants: userId },
        });
        const newCount = await GroupMember.countDocuments({ groupId: group._id, isActive: true });
        await Group.findByIdAndUpdate(group._id, { memberCount: newCount });

        // System message
        const user = await User.findById(userId).select('name');
        await systemMessage(group.chatId, `${user?.name} joined via invite link`);

        return ApiResponse.success(res, { chatId: group.chatId, groupId: group._id }, 'Joined group');
    } catch (error) {
        next(error);
    }
};

/**
 * POST /groups/:groupId/leave
 * Leave a group
 */
exports.leaveGroup = async (req, res, next) => {
    try {
        const userId = req.user.userId;
        const { groupId } = req.params;

        const group = await Group.findById(groupId);
        if (!group || !group.isActive) {
            return ApiResponse.notFound(res, 'Group not found');
        }

        const membership = await GroupMember.findOne({ groupId, userId, isActive: true });
        if (!membership) {
            return ApiResponse.badRequest(res, 'You are not a member of this group');
        }

        // If superadmin is leaving, transfer to oldest admin or oldest member
        if (membership.role === 'superadmin') {
            const nextAdmin = await GroupMember.findOne({
                groupId,
                userId: { $ne: userId },
                isActive: true,
                role: 'admin',
            }).sort({ joinedAt: 1 });

            if (nextAdmin) {
                nextAdmin.role = 'superadmin';
                await nextAdmin.save();
            } else {
                const nextMember = await GroupMember.findOne({
                    groupId,
                    userId: { $ne: userId },
                    isActive: true,
                }).sort({ joinedAt: 1 });

                if (nextMember) {
                    nextMember.role = 'superadmin';
                    await nextMember.save();
                }
            }
        }

        membership.isActive = false;
        await membership.save();

        // Remove from chat
        await Chat.findByIdAndUpdate(group.chatId, {
            $pull: { participants: userId },
        });

        const newCount = await GroupMember.countDocuments({ groupId, isActive: true });
        await Group.findByIdAndUpdate(groupId, { memberCount: newCount });

        // If no members left, deactivate group
        if (newCount === 0) {
            await Group.findByIdAndUpdate(groupId, { isActive: false });
        }

        // System message
        const user = await User.findById(userId).select('name');
        await systemMessage(group.chatId, `${user?.name} left`);

        return ApiResponse.success(res, null, 'Left group');
    } catch (error) {
        next(error);
    }
};

/**
 * PUT /groups/:groupId/mute
 * Mute/unmute group notifications
 */
exports.muteGroup = async (req, res, next) => {
    try {
        const userId = req.user.userId;
        const { groupId } = req.params;
        const { until } = req.body; // ISO date string or null to unmute

        const membership = await GroupMember.findOne({ groupId, userId, isActive: true });
        if (!membership) {
            return ApiResponse.notFound(res, 'Not a member');
        }

        membership.mutedUntil = until ? new Date(until) : null;
        await membership.save();

        return ApiResponse.success(res, { mutedUntil: membership.mutedUntil });
    } catch (error) {
        next(error);
    }
};

/**
 * PUT /groups/:groupId/settings
 * Update group settings (admin only)
 */
exports.updateSettings = async (req, res, next) => {
    try {
        const userId = req.user.userId;
        const { groupId } = req.params;
        const { onlyAdminsCanSend, onlyAdminsCanEditInfo, approvalRequired } = req.body;

        const adminCheck = await isAdmin(groupId, userId);
        if (!adminCheck) {
            return ApiResponse.forbidden(res, 'Only admins can update settings');
        }

        const updates = {};
        if (onlyAdminsCanSend !== undefined) updates['settings.onlyAdminsCanSend'] = !!onlyAdminsCanSend;
        if (onlyAdminsCanEditInfo !== undefined) updates['settings.onlyAdminsCanEditInfo'] = !!onlyAdminsCanEditInfo;
        if (approvalRequired !== undefined) updates['settings.approvalRequired'] = !!approvalRequired;

        const group = await Group.findByIdAndUpdate(groupId, updates, { new: true });

        return ApiResponse.success(res, { settings: group.settings }, 'Settings updated');
    } catch (error) {
        next(error);
    }
};
