const express = require('express');
const router = express.Router();
const Sale = require('../models/Sale');
const Product = require('../models/Product');
const { createAuditLog } = require('../utils/audit');
const { authenticate, requireActiveTenant, requirePermission } = require('../middleware/auth');

// GET /api/sales
router.get('/', authenticate, requireActiveTenant, async (req, res) => {
  try {
    const tenantId = req.user.role === 'developer' ? req.query.tenantId : req.user.tenantId;
    const { startDate, endDate, page = 1, limit = 50 } = req.query;

    const query = { tenantId };
    if (startDate || endDate) {
      query.saleDate = {};
      if (startDate) query.saleDate.$gte = new Date(startDate);
      if (endDate) query.saleDate.$lte = new Date(endDate);
    }

    const total = await Sale.countDocuments(query);
    const sales = await Sale.find(query)
      .populate('productId', 'name sku')
      .populate('recordedBy', 'name')
      .sort({ saleDate: -1 })
      .skip((page - 1) * limit)
      .limit(parseInt(limit));

    res.json({
      success: true,
      sales,
      pagination: { total, page: parseInt(page), limit: parseInt(limit), pages: Math.ceil(total / limit) }
    });
  } catch (error) {
    res.status(500).json({ success: false, message: 'Server error.' });
  }
});

// POST /api/sales - Record a sale
router.post('/', authenticate, requireActiveTenant, requirePermission('record_sales'), async (req, res) => {
  try {
    const { productId, quantity, unitPrice, paymentMethod, customerName, notes } = req.body;

    if (!productId || !quantity) {
      return res.status(400).json({ success: false, message: 'Product and quantity required.' });
    }

    const tenantId = req.user.role === 'developer' ? req.body.tenantId : req.user.tenantId;

    const product = await Product.findOne({ _id: productId, tenantId });
    if (!product) {
      return res.status(404).json({ success: false, message: 'Product not found.' });
    }

    if (product.currentStock < quantity) {
      return res.status(400).json({ success: false, message: `Insufficient stock. Available: ${product.currentStock}` });
    }

    const price = unitPrice || product.sellingPrice;
    const totalAmount = price * quantity;
    const profit = (price - product.costPrice) * quantity;

    const sale = new Sale({
      tenantId,
      productId,
      quantity,
      unitPrice: price,
      costPrice: product.costPrice,
      totalAmount,
      profit,
      paymentMethod: paymentMethod || 'cash',
      customerName,
      notes,
      recordedBy: req.userId
    });
    await sale.save();

    // Deduct stock
    product.currentStock -= quantity;
    await product.save();

    await createAuditLog({
      tenantId,
      eventType: 'sale_recorded',
      userId: req.userId,
      userRole: req.user.role,
      action: `Recorded sale: ${quantity}x ${product.name}`,
      details: { productName: product.name, quantity, totalAmount, profit },
      ipAddress: req.ip
    });

    res.status(201).json({
      success: true,
      message: 'Sale recorded.',
      sale: {
        id: sale._id,
        productName: product.name,
        quantity,
        unitPrice: price,
        totalAmount,
        profit,
        saleDate: sale.saleDate
      }
    });
  } catch (error) {
    console.error('Record sale error:', error);
    res.status(500).json({ success: false, message: 'Server error.' });
  }
});

module.exports = router;
