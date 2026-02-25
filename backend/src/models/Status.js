const mongoose = require('mongoose');

const statusSchema = new mongoose.Schema(
    {
        userId: {
            type: mongoose.Schema.Types.ObjectId,
            ref: 'User',
            required: true,
            index: true,
        },
        type: {
            type: String,
            enum: ['text', 'image', 'video'],
            required: true,
        },
        content: {
            type: String,
            default: '',
        },
        backgroundColor: {
            type: String,
            default: '#075E54', // WhatsApp dark green
        },
        media: {
            url: { type: String, default: '' },
            thumbnail: { type: String, default: '' },
            mimeType: { type: String, default: '' },
        },
        viewers: [
            {
                userId: {
                    type: mongoose.Schema.Types.ObjectId,
                    ref: 'User',
                },
                viewedAt: {
                    type: Date,
                    default: Date.now,
                },
            },
        ],
        expiresAt: {
            type: Date,
            required: true,
            index: { expires: 0 }, // TTL index — MongoDB auto-deletes when expired
        },
    },
    {
        timestamps: true,
    }
);

// Index for efficient querying of contacts' statuses
statusSchema.index({ userId: 1, expiresAt: 1 });
// Removed duplicate index to allow TTL index defined in schema to work properly

module.exports = mongoose.model('Status', statusSchema);
