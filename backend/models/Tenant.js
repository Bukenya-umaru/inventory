const mongoose = require('mongoose');

const tenantSchema = new mongoose.Schema({
  businessName: {
    type: String,
    required: true,
    trim: true
  },
  businessType: {
    type: String,
    enum: ['Retail', 'Wholesale', 'Manufacturing', 'Service', 'Other'],
    default: 'Retail'
  },
  businessLogo: {
    type: String
  },
  phoneNumber: {
    type: String,
    required: true
  },
  address: {
    type: String
  },
  taxId: {
    type: String
  },
  email: {
    type: String,
    required: true
  },
  ownerName: {
    type: String,
    required: true
  },
  // Account Status
  status: {
    type: String,
    enum: ['active', 'suspended', 'deleted'],
    default: 'active'
  },
  suspensionReason: {
    type: String
  },
  suspensionDate: {
    type: Date
  },
  reactivationDate: {
    type: Date
  },
  deletionReason: {
    type: String
  },
  deletionDate: {
    type: Date
  },
  subscriptionPlan: {
    type: String,
    enum: ['Basic', 'Premium', 'Enterprise'],
    default: 'Basic'
  },
  maxEmployees: {
    type: Number,
    default: 10
  },
  startDate: {
    type: Date,
    default: Date.now
  },
  createdBy: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User'
  },
  createdAt: {
    type: Date,
    default: Date.now
  },
  updatedAt: {
    type: Date,
    default: Date.now
  }
});

tenantSchema.pre('save', function(next) {
  this.updatedAt = new Date();
  next();
});

module.exports = mongoose.model('Tenant', tenantSchema);
