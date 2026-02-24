const mongoose = require('mongoose');

const callSchema = new mongoose.Schema(
    {
        callerId: {
            type: mongoose.Schema.Types.ObjectId,
            ref: 'User',
            required: true,
        },
        receiverId: {
            type: mongoose.Schema.Types.ObjectId,
            ref: 'User',
            required: true,
        },
        type: {
            type: String,
            enum: ['audio', 'video'],
            required: true,
            default: 'audio',
        },
        status: {
            type: String,
            enum: ['missed', 'completed', 'declined'],
            required: true,
        },
        duration: {
            type: Number,
            default: 0, // In seconds, 0 for missed/declined
        },
        timestamp: {
            type: Date,
            default: Date.now,
        },
    },
    {
        timestamps: true,
    }
);

// Optional composite index to fast-query users' history
callSchema.index({ callerId: 1, receiverId: 1 });
callSchema.index({ timestamp: -1 });

module.exports = mongoose.model('Call', callSchema);
