const mongoose = require('mongoose');

const passwordViewLogSchema = new mongoose.Schema({
  tenantId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Tenant',
    default: null
  },
  viewerId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  viewerRole: {
    type: String,
    enum: ['developer', 'admin'],
    required: true
  },
  targetUserId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  targetRole: {
    type: String,
    enum: ['admin', 'employee'],
    required: true
  },
  viewReason: {
    type: String
  },
  ipAddress: {
    type: String
  },
  userAgent: {
    type: String
  },
  timestamp: {
    type: Date,
    default: Date.now
  }
});

passwordViewLogSchema.index({ tenantId: 1, timestamp: -1 });
passwordViewLogSchema.index({ viewerId: 1 });
passwordViewLogSchema.index({ targetUserId: 1 });

module.exports = mongoose.model('PasswordViewLog', passwordViewLogSchema);
