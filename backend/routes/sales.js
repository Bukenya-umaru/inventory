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
      if (endDate) {
        const end = new Date(endDate);
        end.setHours(23, 59, 59, 999);
        query.saleDate.$lte = end;
      }
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
    const { productId, quantity, unitPrice, saleUnit: reqSaleUnit, paymentMethod, customerName, notes } = req.body;

    if (!productId || !quantity) {
      return res.status(400).json({ success: false, message: 'Product and quantity required.' });
    }

    const tenantId = req.user.role === 'developer' ? req.body.tenantId : req.user.tenantId;

    const product = await Product.findOne({ _id: productId, tenantId });
    if (!product) {
      return res.status(404).json({ success: false, message: 'Product not found.' });
    }

    // Determine sale unit: default to product's sellingUnit if not specified
    let saleUnit = reqSaleUnit || product.sellingUnit || 'piece';
    if (!['piece', 'box'].includes(saleUnit)) saleUnit = 'piece';

    let price, costPrice, availableStock, boxOpened = false;
    if (saleUnit === 'box') {
      price = unitPrice || product.boxSellingPrice || (product.sellingPrice * (product.unitsPerBox || 1));
      costPrice = product.boxCostPrice || (product.costPrice * (product.unitsPerBox || 1));
      availableStock = product.stockBoxes || 0;
    } else {
      price = unitPrice || product.sellingPrice;
      costPrice = product.costPrice;
      // Total available pieces = loose pieces + pieces inside full boxes
      availableStock = (product.currentStock || 0) + ((product.stockBoxes || 0) * (product.unitsPerBox || 1));
    }

    if (availableStock < quantity) {
      return res.status(400).json({ success: false, message: `Insufficient stock. Available: ${availableStock} ${saleUnit}s` });
    }

    const totalAmount = price * quantity;
    const profit = (price - costPrice) * quantity;

    const sale = new Sale({
      tenantId,
      productId,
      quantity,
      unitPrice: price,
      costPrice,
      totalAmount,
      profit,
      saleUnit,
      paymentMethod: paymentMethod || 'cash',
      customerName,
      notes,
      recordedBy: req.userId
    });
    await sale.save();

    // Deduct stock
    if (saleUnit === 'box') {
      product.stockBoxes -= quantity;
    } else {
      let piecesNeeded = quantity;
      // First use loose pieces
      const looseAvailable = product.currentStock || 0;
      if (looseAvailable >= piecesNeeded) {
        product.currentStock -= piecesNeeded;
      } else {
        // Use all loose pieces first
        piecesNeeded -= looseAvailable;
        product.currentStock = 0;
        // Open full boxes to get more pieces
        while (piecesNeeded > 0 && (product.stockBoxes || 0) > 0) {
          product.stockBoxes -= 1;
          const piecesInBox = product.unitsPerBox || 1;
          if (piecesInBox >= piecesNeeded) {
            product.currentStock = piecesInBox - piecesNeeded;
            piecesNeeded = 0;
          } else {
            piecesNeeded -= piecesInBox;
          }
          boxOpened = true;
        }
      }
    }
    await product.save();

    await createAuditLog({
      tenantId,
      eventType: 'sale_recorded',
      userId: req.userId,
      userRole: req.user.role,
      action: `Recorded sale: ${quantity}x ${product.name} (${saleUnit})`,
      details: { productName: product.name, quantity, saleUnit, totalAmount, profit },
      ipAddress: req.ip
    });

    res.status(201).json({
      success: true,
      message: boxOpened ? 'Sale recorded. A box was opened to fulfill piece order.' : 'Sale recorded.',
      sale: {
        id: sale._id,
        productName: product.name,
        quantity,
        saleUnit,
        unitPrice: price,
        totalAmount,
        profit,
        boxOpened,
        saleDate: sale.saleDate
      }
    });
  } catch (error) {
    console.error('Record sale error:', error);
    res.status(500).json({ success: false, message: 'Server error.' });
  }
});

module.exports = router;
