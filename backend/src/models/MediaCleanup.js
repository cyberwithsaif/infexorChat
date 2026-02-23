const mongoose = require('mongoose');

const mediaCleanupSchema = new mongoose.Schema({
    // The relative URL path of the media file (e.g. /uploads/images/abc.jpg)
    fileUrl: {
        type: String,
        required: true,
        index: true,
    },
    // When this file should be deleted (1 day after download)
    deleteAt: {
        type: Date,
        required: true,
        index: true,
    },
    // Who downloaded it
    downloadedBy: {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User',
    },
    createdAt: {
        type: Date,
        default: Date.now,
    },
});

module.exports = mongoose.model('MediaCleanup', mediaCleanupSchema);
