const mongoose = require('mongoose');

const broadcastSchema = new mongoose.Schema(
  {
    title: {
      type: String,
      required: true,
      trim: true,
      maxlength: 200,
    },
    content: {
      type: String,
      required: true,
      maxlength: 1000,
    },
    type: {
      type: String,
      enum: ['push', 'in_app', 'both'],
      default: 'push',
    },
    segment: {
      type: String,
      enum: ['all', 'active', 'inactive', 'android', 'ios', 'custom'],
      default: 'all',
    },
    customFilter: {
      // For 'custom' segment
      registeredAfter: { type: Date, default: null },
      registeredBefore: { type: Date, default: null },
      platform: { type: String, default: null },
    },
    scheduledAt: {
      type: Date,
      default: null, // null = send immediately
    },
    sentAt: {
      type: Date,
      default: null,
    },
    status: {
      type: String,
      enum: ['draft', 'scheduled', 'sending', 'sent', 'failed'],
      default: 'draft',
    },
    stats: {
      targetCount: { type: Number, default: 0 },
      sentCount: { type: Number, default: 0 },
      failedCount: { type: Number, default: 0 },
      openedCount: { type: Number, default: 0 },
    },
    createdBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Admin',
      required: true,
    },
  },
  {
    timestamps: true,
  }
);

broadcastSchema.index({ status: 1, scheduledAt: 1 });
broadcastSchema.index({ createdBy: 1 });

module.exports = mongoose.model('Broadcast', broadcastSchema);
