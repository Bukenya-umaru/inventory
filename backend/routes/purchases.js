const express = require('express');
const router = express.Router();
const Purchase = require('../models/Purchase');
const Product = require('../models/Product');
const { createAuditLog } = require('../utils/audit');
const { authenticate, requireActiveTenant, requirePermission } = require('../middleware/auth');

// GET /api/purchases
router.get('/', authenticate, requireActiveTenant, async (req, res) => {
  try {
    const tenantId = req.user.role === 'developer' ? req.query.tenantId : req.user.tenantId;
    const { page = 1, limit = 50 } = req.query;

    const query = { tenantId };
    const total = await Purchase.countDocuments(query);
    const purchases = await Purchase.find(query)
      .populate('productId', 'name sku')
      .populate('recordedBy', 'name')
      .sort({ purchaseDate: -1 })
      .skip((page - 1) * limit)
      .limit(parseInt(limit));

    res.json({
      success: true,
      purchases,
      pagination: { total, page: parseInt(page), limit: parseInt(limit), pages: Math.ceil(total / limit) }
    });
  } catch (error) {
    res.status(500).json({ success: false, message: 'Server error.' });
  }
});

// POST /api/purchases - Add stock (purchase)
router.post('/', authenticate, requireActiveTenant, requirePermission('create_products'), async (req, res) => {
  try {
    const { productId, quantity, purchaseUnit: reqPurchaseUnit, unitCost, supplier, notes } = req.body;

    if (!productId || !quantity) {
      return res.status(400).json({ success: false, message: 'Product and quantity required.' });
    }

    const tenantId = req.user.role === 'developer' ? req.body.tenantId : req.user.tenantId;

    const product = await Product.findOne({ _id: productId, tenantId });
    if (!product) {
      return res.status(404).json({ success: false, message: 'Product not found.' });
    }

    // Determine purchase unit — default to box
    let purchaseUnit = reqPurchaseUnit || 'box';
    if (!['piece', 'box'].includes(purchaseUnit)) purchaseUnit = 'box';

    const cost = unitCost || (purchaseUnit === 'box' ? (product.boxCostPrice || product.costPrice * (product.unitsPerBox || 1)) : product.costPrice);
    const totalCost = cost * quantity;

    const purchase = new Purchase({
      tenantId,
      productId,
      quantity,
      purchaseUnit,
      unitCost: cost,
      totalCost,
      supplier,
      notes,
      recordedBy: req.userId
    });
    await purchase.save();

    // Add stock
    if (purchaseUnit === 'box') {
      product.stockBoxes += quantity;
    } else {
      product.currentStock += quantity;
    }
    await product.save();

    await createAuditLog({
      tenantId,
      eventType: 'purchase_recorded',
      userId: req.userId,
      userRole: req.user.role,
      action: `Recorded purchase: ${quantity}x ${product.name} (${purchaseUnit})`,
      details: { productName: product.name, quantity, purchaseUnit, unitCost: cost, totalCost, supplier },
      ipAddress: req.ip
    });

    res.status(201).json({
      success: true,
      message: 'Stock added.',
      purchase: {
        id: purchase._id,
        productName: product.name,
        quantity,
        purchaseUnit,
        unitCost: cost,
        totalCost,
        supplier,
        purchaseDate: purchase.purchaseDate
      }
    });
  } catch (error) {
    console.error('Record purchase error:', error);
    res.status(500).json({ success: false, message: 'Server error.' });
  }
});

module.exports = router;
