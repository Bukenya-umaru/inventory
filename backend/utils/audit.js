const AuditLog = require('../models/AuditLog');

/**
 * Create an audit log entry
 */
const createAuditLog = async ({
  tenantId = null,
  eventType,
  severity = 'info',
  userId = null,
  userRole = null,
  action = '',
  details = {},
  ipAddress = '',
  userAgent = ''
}) => {
  try {
    const log = new AuditLog({
      tenantId,
      eventType,
      severity,
      userId,
      userRole,
      action,
      details,
      ipAddress,
      userAgent
    });
    await log.save();
    return log;
  } catch (error) {
    console.error('Audit log error:', error);
  }
};

module.exports = { createAuditLog };
