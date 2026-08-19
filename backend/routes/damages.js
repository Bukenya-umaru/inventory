const express = require('express');
const router = express.Router();
const Damage = require('../models/Damage');
const Product = require('../models/Product');
const { createAuditLog } = require('../utils/audit');
const { authenticate, requireActiveTenant, requirePermission } = require('../middleware/auth');

// GET /api/damages
router.get('/', authenticate, requireActiveTenant, async (req, res) => {
  try {
    const tenantId = req.user.role === 'developer' ? req.query.tenantId : req.user.tenantId;
    const { page = 1, limit = 50 } = req.query;

    const query = { tenantId };
    const total = await Damage.countDocuments(query);
    const damages = await Damage.find(query)
      .populate('productId', 'name sku')
      .populate('reportedBy', 'name')
      .sort({ reportDate: -1 })
      .skip((page - 1) * limit)
      .limit(parseInt(limit));

    res.json({
      success: true,
      damages,
      pagination: { total, page: parseInt(page), limit: parseInt(limit), pages: Math.ceil(total / limit) }
    });
  } catch (error) {
    res.status(500).json({ success: false, message: 'Server error.' });
  }
});

// POST /api/damages - Report damaged goods
router.post('/', authenticate, requireActiveTenant, requirePermission('record_damages'), async (req, res) => {
  try {
    const { productId, quantity, reason } = req.body;

    if (!productId || !quantity || !reason) {
      return res.status(400).json({ success: false, message: 'Product, quantity, and reason required.' });
    }

    const tenantId = req.user.role === 'developer' ? req.body.tenantId : req.user.tenantId;

    const product = await Product.findOne({ _id: productId, tenantId });
    if (!product) {
      return res.status(404).json({ success: false, message: 'Product not found.' });
    }

    if (product.currentStock < quantity) {
      return res.status(400).json({ success: false, message: `Insufficient stock. Available: ${product.currentStock}` });
    }

    const estimatedLoss = product.costPrice * quantity;

    const damage = new Damage({
      tenantId,
      productId,
      quantity,
      reason,
      estimatedLoss,
      reportedBy: req.userId
    });
    await damage.save();

    // Deduct stock
    product.currentStock -= quantity;
    await product.save();

    await createAuditLog({
      tenantId,
      eventType: 'damage_recorded',
      severity: 'warning',
      userId: req.userId,
      userRole: req.user.role,
      action: `Reported damage: ${quantity}x ${product.name}`,
      details: { productName: product.name, quantity, reason, estimatedLoss },
      ipAddress: req.ip
    });

    res.status(201).json({
      success: true,
      message: 'Damage reported.',
      damage: {
        id: damage._id,
        productName: product.name,
        quantity,
        reason,
        estimatedLoss,
        reportDate: damage.reportDate
      }
    });
  } catch (error) {
    console.error('Report damage error:', error);
    res.status(500).json({ success: false, message: 'Server error.' });
  }
});

module.exports = router;
