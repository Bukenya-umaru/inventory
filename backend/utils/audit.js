const AuditLog = require('../models/AuditLog');

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
};

module.exports = { createAuditLog };