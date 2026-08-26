const mongoose = require('mongoose');

const auditLogSchema = new mongoose.Schema({
  tenantId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Tenant',
    default: null
  },
  eventType: {
    type: String,
    enum: [
      'business_created', 'business_suspended', 'business_reactivated', 'business_deleted',
      'admin_created', 'employee_created_primary', 'employee_created_backup',
      'employee_deleted', 'employee_permissions_updated',
      'password_viewed', 'password_changed',
      'category_created', 'category_updated', 'category_deleted',
      'product_created', 'product_updated', 'product_deleted',
      'sale_recorded', 'damage_recorded', 'purchase_recorded', 'stock_merged',
      'login_success', 'login_failed'
    ],
    required: true
  },
  severity: {
    type: String,
    enum: ['info', 'warning', 'error', 'critical'],
    default: 'info'
  },
  userId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User'
  },
  userRole: {
    type: String,
    enum: ['developer', 'admin', 'employee']
  },
  action: {
    type: String
  },
  details: {
    type: mongoose.Schema.Types.Mixed
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

auditLogSchema.index({ tenantId: 1, timestamp: -1 });
auditLogSchema.index({ eventType: 1 });
auditLogSchema.index({ userId: 1 });

module.exports = mongoose.model('AuditLog', auditLogSchema);
