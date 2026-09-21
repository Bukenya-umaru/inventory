const express = require('express');
const router = express.Router();
const AuditLog = require('../models/AuditLog');
const User = require('../models/User');
const { authenticate, requireRole } = require('../middleware/auth');

const INVENTORY_EVENT_TYPES = [
  'sale_recorded', 'damage_recorded', 'purchase_recorded', 'stock_merged',
  'low_stock_alert',
  'product_created', 'product_updated', 'product_deleted',
  'category_created', 'category_updated', 'category_deleted'
];

router.get('/activity', authenticate, requireRole('admin', 'employee'), async (req, res) => {
  try {
    const { types, limit = 50 } = req.query;
    const query = { tenantId: req.user.tenantId };

    query.userId = { $ne: req.user._id };

    if (types) {
      const arr = String(types).split(',').map(s => s.trim()).filter(t => INVENTORY_EVENT_TYPES.includes(t));
      query.eventType = { $in: arr };
    } else {
      query.eventType = { $in: INVENTORY_EVENT_TYPES };
    }

    const logs = await AuditLog.find(query)
      .populate('userId', 'name role')
      .sort({ timestamp: -1 })
      .limit(Math.min(parseInt(limit) || 50, 200));

    const readAt = req.user.lastActivityReadAt;
    const unreadCount = readAt
      ? await AuditLog.countDocuments({ ...query, timestamp: { $gt: readAt } })
      : logs.length;

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

router.get('/', authenticate, async (req, res) => {
  try {
    const { eventType, severity, startDate, endDate, page = 1, limit = 50 } = req.query;

    let query = {};

    if (req.user.role === 'developer') {

    } else if (req.user.role === 'admin') {
      query.tenantId = req.user.tenantId;
    } else {
      return res.status(403).json({ success: false, message: 'Access denied.' });
    }

    if (eventType) query.eventType = eventType;
    if (severity) query.severity = severity;
    if (startDate || endDate) {
      query.timestamp = {};
      if (startDate) query.timestamp.$gte = new Date(startDate);
      if (endDate) query.timestamp.$lte = new Date(endDate);
    }

    const total = await AuditLog.countDocuments(query);
    const logs = await AuditLog.find(query)
      .populate('userId', 'name email role')
      .populate('tenantId', 'businessName')
      .sort({ timestamp: -1 })
      .skip((page - 1) * limit)
      .limit(parseInt(limit));

    res.json({
      success: true,
      logs,
      pagination: { total, page: parseInt(page), limit: parseInt(limit), pages: Math.ceil(total / limit) }
    });
  } catch (error) {
    res.status(500).json({ success: false, message: 'Server error.' });
  }
});

module.exports = router;