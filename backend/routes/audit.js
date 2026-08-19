const express = require('express');
const router = express.Router();
const AuditLog = require('../models/AuditLog');
const { authenticate, requireRole } = require('../middleware/auth');

// GET /api/audit - View audit logs
router.get('/', authenticate, async (req, res) => {
  try {
    const { eventType, severity, startDate, endDate, page = 1, limit = 50 } = req.query;

    let query = {};

    if (req.user.role === 'developer') {
      // Developer sees all logs
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
