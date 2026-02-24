const mongoose = require('mongoose');

const messageSchema = new mongoose.Schema(
  {
    chatId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Chat',
      required: true,
    },
    senderId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      default: null,
    },
    type: {
      type: String,
      enum: [
        'text',
        'image',
        'video',
        'audio',
        'voice',
        'document',
        'location',
        'contact',
        'gif',
        'sticker',
        'system',
      ],
      default: 'text',
    },
    content: {
      // Text content or caption
      type: String,
      default: '',
    },
    media: {
      url: { type: String, default: '' },
      thumbnail: { type: String, default: '' },
      mimeType: { type: String, default: '' },
      size: { type: Number, default: 0 }, // bytes
      duration: { type: Number, default: 0 }, // seconds (audio/video)
      width: { type: Number, default: 0 },
      height: { type: Number, default: 0 },
      fileName: { type: String, default: '' },
    },
    location: {
      latitude: { type: Number },
      longitude: { type: Number },
      address: { type: String, default: '' },
    },
    contactShare: {
      name: { type: String, default: '' },
      phone: { type: String, default: '' },
    },
    replyTo: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Message',
      default: null,
    },
    forwardedFrom: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Message',
      default: null,
    },
    reactions: [
      {
        userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
        emoji: { type: String },
        createdAt: { type: Date, default: Date.now },
      },
    ],
    status: {
      type: String,
      enum: ['sending', 'sent', 'delivered', 'read'],
      default: 'sent',
    },
    deliveredTo: [
      {
        userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
        at: { type: Date, default: Date.now },
      },
    ],
    readBy: [
      {
        userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
        at: { type: Date, default: Date.now },
      },
    ],
    starredBy: [
      {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User',
      },
    ],
    deletedFor: [
      {
        type: mongoose.Schema.Types.ObjectId,
        ref: 'User',
      },
    ],
    deletedForEveryone: {
      type: Boolean,
      default: false,
    },
    isEdited: {
      type: Boolean,
      default: false,
    },
    isAI: {
      type: Boolean,
      default: false,
    },
  },
  {
    timestamps: true,
  }
);

messageSchema.index({ chatId: 1, createdAt: -1 });
messageSchema.index({ senderId: 1 });
messageSchema.index({ chatId: 1, senderId: 1 });
messageSchema.index({ 'starredBy': 1 });
messageSchema.index({ type: 1 });

module.exports = mongoose.model('Message', messageSchema);
