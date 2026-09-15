const mongoose = require('mongoose');

const damageSchema = new mongoose.Schema({
  tenantId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Tenant',
    required: true
  },
  productId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Product',
    required: true
  },
  quantity: {
    type: Number,
    required: true,
    min: 1
  },
  damageUnit: {
    type: String,
    enum: ['piece', 'box'],
    default: 'piece'
  },
  reason: {
    type: String,
    required: true
  },
  estimatedLoss: {
    type: Number,
    default: 0
  },
  reportedBy: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  status: {
    type: String,
    enum: ['reported', 'investigating', 'resolved'],
    default: 'reported'
  },
  reportDate: {
    type: Date,
    default: Date.now
  },
  createdAt: {
    type: Date,
    default: Date.now
  }
});

damageSchema.index({ tenantId: 1, reportDate: -1 });

module.exports = mongoose.model('Damage', damageSchema);