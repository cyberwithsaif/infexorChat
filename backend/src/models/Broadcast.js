const mongoose = require('mongoose');

const broadcastSchema = new mongoose.Schema(
  {
    title: {
      type: String,
      required: true,
      trim: true,
      maxlength: 200,
    },
    message: {
      type: String,
      required: true,
      maxlength: 1000,
    },
    segment: {
      type: String,
      enum: ['active', 'all', 'banned', 'custom'],
      default: 'all',
      required: true,
    },
    platform: {
      type: String,
      enum: ['android', 'ios', 'both'],
      default: 'both',
      required: true,
    },
    status: {
      type: String,
      enum: ['draft', 'queued', 'sending', 'sent', 'failed'],
      default: 'draft',
      required: true,
    },
    totalRecipients: {
      type: Number,
      default: 0,
    },
    successCount: {
      type: Number,
      default: 0,
    },
    failureCount: {
      type: Number,
      default: 0,
    },
    createdBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Admin',
      required: true,
    },
    sentAt: {
      type: Date,
      default: null,
    },
  },
  {
    timestamps: true,
  }
);

// High-performance indexes for sorting and filtering by admin pane
broadcastSchema.index({ segment: 1 });
broadcastSchema.index({ status: 1 });
broadcastSchema.index({ createdAt: -1 });

module.exports = mongoose.model('Broadcast', broadcastSchema);
