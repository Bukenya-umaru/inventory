const express = require('express');
const router = express.Router();
const AuditLog = require('../models/AuditLog');
const User = require('../models/User');
const { authenticate, requireRole } = require('../middleware/auth');

const BUSINESS_EVENT_TYPES = [
  'employee_created_primary', 'employee_created_backup', 'employee_deleted',
  'employee_permissions_updated', 'employee_suspended', 'employee_reactivated',
  'category_created', 'category_updated', 'category_deleted',
  'product_created', 'product_updated', 'product_deleted',
  'sale_recorded', 'sale_approved', 'damage_recorded',
  'purchase_recorded', 'purchase_edited', 'purchase_approved', 'stock_merged',
  'expense_recorded', 'credit_paid', 'low_stock_alert',
  'supplier_created', 'supplier_updated', 'supplier_deleted'
];

async function addSearchFilter(query, search, tenantId) {
  if (!search || !String(search).trim()) return;
  const escaped = String(search).trim().replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const regex = new RegExp(escaped, 'i');
  const actorQuery = {
    $or: [{ name: regex }, { email: regex }]
  };
  if (tenantId) actorQuery.tenantId = tenantId;
  const actors = await User.find(actorQuery).select('_id');
  query.$or = [
    { action: regex },
    { eventType: regex },
    { userId: { $in: actors.map((actor) => actor._id) } }
  ];
}

router.get('/activity', authenticate, requireRole('admin', 'employee'), async (req, res) => {
  try {
    const { types, limit = 50, search } = req.query;
    const query = { tenantId: req.user.tenantId };

    query.userId = { $ne: req.user._id };

    if (types) {
      const arr = String(types).split(',').map(s => s.trim()).filter(t => BUSINESS_EVENT_TYPES.includes(t));
      query.eventType = { $in: arr };
    } else {
      query.eventType = { $in: BUSINESS_EVENT_TYPES };
    }

    const unreadBaseQuery = { ...query };
    await addSearchFilter(query, search, req.user.tenantId);

    const requestedLimit = parseInt(limit, 10) || 50;
    const pageSize = Math.min(Math.max(requestedLimit, 1), 200);
    const logs = await AuditLog.find(query)
      .populate('userId', 'name role')
      .sort({ timestamp: -1 })
      .limit(pageSize);

    const readAt = req.user.lastActivityReadAt;
    const unreadQuery = readAt
      ? { ...unreadBaseQuery, timestamp: { $gt: readAt } }
      : unreadBaseQuery;
    const unreadCount = await AuditLog.countDocuments(unreadQuery);

    res.json({ success: true, logs, unreadCount });
  } catch (error) {
    console.error('Get activity error:', error);
    res.status(500).json({ success: false, message: 'Server error.' });
  }
});

router.post('/activity/seen', authenticate, requireRole('admin', 'employee'), async (req, res) => {
  try {
    await User.findByIdAndUpdate(req.user._id, { lastActivityReadAt: new Date() });
    res.json({ success: true });
  } catch (error) {
    res.status(500).json({ success: false, message: 'Server error.' });
  }
});

router.get('/business-activity', authenticate, requireRole('admin'), async (req, res) => {
  try {
    const { eventType, severity, startDate, endDate, page = 1, limit = 50, search } = req.query;
    const currentPage = Math.max(1, parseInt(page, 10) || 1);
    const pageSize = Math.min(200, Math.max(1, parseInt(limit, 10) || 50));
    const query = {
      tenantId: req.user.tenantId,
      eventType: { $in: BUSINESS_EVENT_TYPES }
    };

    if (eventType && BUSINESS_EVENT_TYPES.includes(String(eventType))) {
      query.eventType = eventType;
    }
    if (severity) query.severity = severity;
    if (startDate || endDate) {
      query.timestamp = {};
      if (startDate) query.timestamp.$gte = new Date(startDate);
      if (endDate) query.timestamp.$lte = new Date(endDate);
    }

    await addSearchFilter(query, search, req.user.tenantId);

    const total = await AuditLog.countDocuments(query);
    const logs = await AuditLog.find(query)
      .populate('userId', 'name email role')
      .sort({ timestamp: -1 })
      .skip((currentPage - 1) * pageSize)
      .limit(pageSize);

    res.json({
      success: true,
      logs,
      pagination: { total, page: currentPage, limit: pageSize, pages: Math.ceil(total / pageSize) }
    });
  } catch (error) {
    console.error('Get business activity error:', error);
    res.status(500).json({ success: false, message: 'Server error.' });
  }
});

router.get('/', authenticate, requireRole('developer'), async (req, res) => {
  try {
    const { eventType, severity, startDate, endDate, page = 1, limit = 50, search } = req.query;
    const currentPage = Math.max(1, parseInt(page, 10) || 1);
    const pageSize = Math.min(200, Math.max(1, parseInt(limit, 10) || 50));

    const query = {};

    if (eventType) query.eventType = eventType;
    if (severity) query.severity = severity;
    if (startDate || endDate) {
      query.timestamp = {};
      if (startDate) query.timestamp.$gte = new Date(startDate);
      if (endDate) query.timestamp.$lte = new Date(endDate);
    }

    await addSearchFilter(query, search);

    const total = await AuditLog.countDocuments(query);
    const logs = await AuditLog.find(query)
      .populate('userId', 'name email role')
      .populate('tenantId', 'businessName')
      .sort({ timestamp: -1 })
      .skip((currentPage - 1) * pageSize)
      .limit(pageSize);

    res.json({
      success: true,
      logs,
      pagination: { total, page: currentPage, limit: pageSize, pages: Math.ceil(total / pageSize) }
    });
  } catch (error) {
    res.status(500).json({ success: false, message: 'Server error.' });
  }
});

module.exports = router;