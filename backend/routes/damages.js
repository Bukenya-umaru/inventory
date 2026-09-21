const express = require('express');
const router = express.Router();
const Damage = require('../models/Damage');
const Product = require('../models/Product');
const { createAuditLog } = require('../utils/audit');
const { notifyLowStock } = require('../utils/notifications');
const { authenticate, requireActiveTenant, requirePermission } = require('../middleware/auth');

router.get('/', authenticate, requireActiveTenant, async (req, res) => {
  try {
    const tenantId = req.user.role === 'developer' ? req.query.tenantId : req.user.tenantId;
    const { startDate, endDate, page = 1, limit = 50 } = req.query;

    const query = { tenantId };
    if (startDate || endDate) {
      query.reportDate = {};
      if (startDate) query.reportDate.$gte = new Date(startDate);
      if (endDate) {
        const end = new Date(endDate);
        end.setHours(23, 59, 59, 999);
        query.reportDate.$lte = end;
      }
    }
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

router.post('/', authenticate, requireActiveTenant, requirePermission('record_damages'), async (req, res) => {
  try {
    const { productId, quantity, damageUnit: reqDamageUnit, reason } = req.body;

    if (!productId || !quantity || !reason) {
      return res.status(400).json({ success: false, message: 'Product, quantity, and reason required.' });
    }

    const tenantId = req.user.role === 'developer' ? req.body.tenantId : req.user.tenantId;

    const product = await Product.findOne({ _id: productId, tenantId });
    if (!product) {
      return res.status(404).json({ success: false, message: 'Product not found.' });
    }

    let damageUnit = reqDamageUnit || product.sellingUnit || 'piece';
    if (!['piece', 'box'].includes(damageUnit)) damageUnit = 'piece';

    let costPrice, availableStock;
    if (damageUnit === 'box') {
      costPrice = product.boxCostPrice || (product.costPrice * (product.unitsPerBox || 1));
      availableStock = product.stockBoxes || 0;
    } else {
      costPrice = product.costPrice;

      availableStock = (product.currentStock || 0) + ((product.stockBoxes || 0) * (product.unitsPerBox || 1));
    }

    if (availableStock < quantity) {
      return res.status(400).json({ success: false, message: `Insufficient stock. Available: ${availableStock} ${damageUnit}s` });
    }

    const estimatedLoss = costPrice * quantity;

    const damage = new Damage({
      tenantId,
      productId,
      quantity,
      damageUnit,
      reason,
      estimatedLoss,
      reportedBy: req.userId
    });
    await damage.save();

    if (damageUnit === 'box') {
      product.stockBoxes -= quantity;
    } else {
      let piecesNeeded = quantity;
      const looseAvailable = product.currentStock || 0;
      if (looseAvailable >= piecesNeeded) {
        product.currentStock -= piecesNeeded;
      } else {
        piecesNeeded -= looseAvailable;
        product.currentStock = 0;
        while (piecesNeeded > 0 && (product.stockBoxes || 0) > 0) {
          product.stockBoxes -= 1;
          const piecesInBox = product.unitsPerBox || 1;
          if (piecesInBox >= piecesNeeded) {
            product.currentStock = piecesInBox - piecesNeeded;
            piecesNeeded = 0;
          } else {
            piecesNeeded -= piecesInBox;
          }
        }
      }
    }
    await product.save();

    // Notification: warn the whole business (admin + employees) if the product
    // just dropped to/below its minimum stock level.
    await notifyLowStock(product, { userId: req.userId, userRole: req.user.role }, { reason: 'damage' });

    await createAuditLog({
      tenantId,
      eventType: 'damage_recorded',
      severity: 'warning',
      userId: req.userId,
      userRole: req.user.role,
      action: `Reported damage: ${quantity}x ${product.name} (${damageUnit})`,
      details: { productName: product.name, quantity, damageUnit, reason, estimatedLoss },
      ipAddress: req.ip
    });

    res.status(201).json({
      success: true,
      message: 'Damage reported.',
      damage: {
        id: damage._id,
        productName: product.name,
        quantity,
        damageUnit,
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