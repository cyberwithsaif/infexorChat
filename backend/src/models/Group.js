const mongoose = require('mongoose');
const crypto = require('crypto');

const groupSchema = new mongoose.Schema(
  {
    name: {
      type: String,
      required: true,
      trim: true,
      maxlength: 100,
    },
    description: {
      type: String,
      trim: true,
      maxlength: 500,
      default: '',
    },
    avatar: {
      type: String,
      default: '',
    },
    createdBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
    },
    chatId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Chat',
      default: null,
    },
    inviteLink: {
      type: String,
      unique: true,
      sparse: true,
    },
    inviteLinkEnabled: {
      type: Boolean,
      default: true,
    },
    settings: {
      onlyAdminsCanSend: {
        type: Boolean,
        default: false,
      },
      onlyAdminsCanEditInfo: {
        type: Boolean,
        default: false,
      },
      approvalRequired: {
        type: Boolean,
        default: false,
      },
    },
    maxMembers: {
      type: Number,
      default: 256,
    },
    memberCount: {
      type: Number,
      default: 1,
    },
    isActive: {
      type: Boolean,
      default: true,
    },
  },
  {
    timestamps: true,
  }
);

groupSchema.index({ inviteLink: 1 });
groupSchema.index({ createdBy: 1 });

// Generate invite link before save if not set
groupSchema.pre('save', function () {
  if (!this.inviteLink) {
    this.inviteLink = crypto.randomBytes(16).toString('hex');
  }
});

module.exports = mongoose.model('Group', groupSchema);
