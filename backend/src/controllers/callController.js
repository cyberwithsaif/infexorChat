const Call = require('../models/Call');
const User = require('../models/User');

/**
 * Record a new call log entry
 * @route POST /api/calls
 */
exports.recordCall = async (req, res) => {
    try {
        const { callerId: providedCaller, receiverId, type, status, duration } = req.body;
        const currentUserId = req.user.id;

        if (!receiverId || !type || !status) {
            return res.status(400).json({ message: 'Missing required call parameters' });
        }

        const callerId = providedCaller || currentUserId;

        // Security check: the user logging the call must be either the caller or receiver
        if (callerId !== currentUserId && receiverId !== currentUserId) {
            return res.status(403).json({ message: 'Unauthorized to log this call' });
        }

        // --- Prevent Duplicate Calls ---
        // Both caller and receiver may log the call when it ends
        // We look for identical records (caller, receiver) in the last 15 seconds
        const duplicateWindow = new Date(Date.now() - 15000);
        const existingCall = await Call.findOne({
            callerId,
            receiverId,
            timestamp: { $gte: duplicateWindow }
        });

        if (existingCall) {
            // If the call is already logged by the peer, just return success
            return res.status(200).json({
                success: true,
                message: 'Call already recorded by peer',
                data: existingCall,
            });
        }

        const newCall = await Call.create({
            callerId,
            receiverId,
            type,
            status, // 'missed', 'completed', 'declined'
            duration: duration || 0,
            timestamp: new Date(),
        });

        res.status(201).json({
            success: true,
            message: 'Call recorded successfully',
            data: newCall,
        });
    } catch (error) {
        console.error('Error recording call:', error);
        res.status(500).json({ message: 'Internal server error while recording call' });
    }
};

/**
 * Fetch call history for the current user
 * @route GET /api/calls
 */
exports.getCallHistory = async (req, res) => {
    try {
        const userId = req.user.id;

        // Get calls where user was caller or receiver
        const calls = await Call.find({
            $or: [{ callerId: userId }, { receiverId: userId }],
        })
            .sort({ timestamp: -1 })
            .limit(50) // Adjust limit as needed
            .populate('callerId', 'name avatar phone') // populate caller info
            .populate('receiverId', 'name avatar phone'); // populate receiver info

        res.status(200).json({
            success: true,
            data: calls,
        });
    } catch (error) {
        console.error('Error fetching call history:', error);
        res.status(500).json({ message: 'Internal server error fetching call history' });
    }
};
