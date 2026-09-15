const mongoose = require('mongoose');

const userSchema = new mongoose.Schema({
  name: {
    type: String,
    required: true,
    trim: true
  },
  email: {
    type: String,
    required: true,
    unique: true,
    lowercase: true,
    trim: true
  },

  encryptedPassword: {
    type: String,
    required: true
  },
  passwordIV: {
    type: String,
    required: true
  },

  passwordHash: {
    type: String,
    required: true
  },
  role: {
    type: String,
    enum: ['developer', 'admin', 'employee'],
    required: true
  },
  tenantId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Tenant',
    default: null
  },

  createdBy: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    default: null
  },
  createdByRole: {
    type: String,
    enum: ['developer', 'admin'],
    default: null
  },
  creationReason: {
    type: String,
    enum: ['primary', 'backup'],
    default: 'primary'
  },
  backupReason: {
    type: String
  },

  employeeId: {
    type: String,
    sparse: true
  },
  department: {
    type: String
  },
  position: {
    type: String
  },

  permissions: [{
    type: String,
    enum: [
      'manage_categories', 'create_products', 'edit_products', 'delete_products',
      'record_sales', 'record_purchases', 'record_damages', 'view_inventory',
      'view_transactions', 'view_profits', 'adjust_inventory', 'view_reports'
    ]
  }],
  isActive: {
    type: Boolean,
    default: true
  },
  deletedAt: {
    type: Date
  },
  deletedBy: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User'
  },
  deletionReason: {
    type: String
  },

  passwordViewCount: {
    type: Number,
    default: 0
  },
  lastPasswordView: {
    type: Date
  },
  lastLogin: {
    type: Date
  },

  lastActivityReadAt: {
    type: Date,
    default: null
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

userSchema.pre('save', function(next) {
  this.updatedAt = new Date();
  next();
});

userSchema.index({ tenantId: 1 });
userSchema.index({ role: 1 });

module.exports = mongoose.model('User', userSchema);