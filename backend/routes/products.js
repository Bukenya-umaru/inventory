const express = require('express');
const router = express.Router();
const Product = require('../models/Product');
const Category = require('../models/Category');
const { createAuditLog } = require('../utils/audit');
const { authenticate, requireActiveTenant, requirePermission } = require('../middleware/auth');

// GET /api/products
router.get('/', authenticate, requireActiveTenant, async (req, res) => {
  try {
    const tenantId = req.user.role === 'developer' ? req.query.tenantId : req.user.tenantId;
    const { category, search, lowStock, page = 1, limit = 50 } = req.query;

    const query = { tenantId, isActive: true };
    if (category) query.categoryId = category;
    if (search) {
      query.$or = [
        { name: { $regex: search, $options: 'i' } },
        { sku: { $regex: search, $options: 'i' } }
      ];
    }
    if (lowStock === 'true') {
      query.$expr = { $lte: ['$currentStock', '$minimumStock'] };
    }

    const total = await Product.countDocuments(query);
    const products = await Product.find(query)
      .populate('categoryId', 'name')
      .sort({ createdAt: -1 })
      .skip((page - 1) * limit)
      .limit(parseInt(limit));

    res.json({
      success: true,
      products,
      pagination: { total, page: parseInt(page), limit: parseInt(limit), pages: Math.ceil(total / limit) }
    });
  } catch (error) {
    res.status(500).json({ success: false, message: 'Server error.' });
  }
});

// POST /api/products
router.post('/', authenticate, requireActiveTenant, requirePermission('create_products'), async (req, res) => {
  try {
    const { name, description, sku, categoryId, costPrice, sellingPrice, currentStock, minimumStock, unit, sellingUnit, unitsPerBox, stockBoxes, boxSellingPrice, boxCostPrice } = req.body;

    if (!name || !categoryId || costPrice === undefined || sellingPrice === undefined) {
      return res.status(400).json({ success: false, message: 'Required fields missing.' });
    }

    const tenantId = req.user.role === 'developer' ? req.body.tenantId : req.user.tenantId;

    // Verify category belongs to tenant
    const category = await Category.findOne({ _id: categoryId, tenantId });
    if (!category) {
      return res.status(400).json({ success: false, message: 'Invalid category.' });
    }

    const product = new Product({
      name,
      description,
      sku,
      categoryId,
      tenantId,
      costPrice,
      sellingPrice,
      currentStock: currentStock || 0,
      minimumStock: minimumStock || 5,
      unit: unit || 'piece',
      sellingUnit: sellingUnit || 'piece',
      unitsPerBox: unitsPerBox || 1,
      stockBoxes: stockBoxes || 0,
      boxSellingPrice: boxSellingPrice,
      boxCostPrice: boxCostPrice,
      createdBy: req.userId
    });

    await product.save();

    await createAuditLog({
      tenantId,
      eventType: 'product_created',
      userId: req.userId,
      userRole: req.user.role,
      action: `Created product: ${name}`,
      details: { name, sku, costPrice, sellingPrice },
      ipAddress: req.ip
    });

    res.status(201).json({ success: true, message: 'Product created.', product });
  } catch (error) {
    console.error('Create product error:', error);
    res.status(500).json({ success: false, message: 'Server error.' });
  }
});

// PUT /api/products/:id
router.put('/:id', authenticate, requireActiveTenant, requirePermission('edit_products'), async (req, res) => {
  try {
    const tenantId = req.user.role === 'developer' ? req.body.tenantId : req.user.tenantId;
    const product = await Product.findOne({ _id: req.params.id, tenantId });
    if (!product) {
      return res.status(404).json({ success: false, message: 'Product not found.' });
    }

    const updates = req.body;
    delete updates.tenantId;
    delete updates.createdBy;

    Object.assign(product, updates);
    await product.save();

    res.json({ success: true, message: 'Product updated.', product });
  } catch (error) {
    res.status(500).json({ success: false, message: 'Server error.' });
  }
});

// DELETE /api/products/:id
router.delete('/:id', authenticate, requireActiveTenant, requirePermission('delete_products'), async (req, res) => {
  try {
    const tenantId = req.user.role === 'developer' ? req.query.tenantId : req.user.tenantId;
    const product = await Product.findOne({ _id: req.params.id, tenantId });
    if (!product) {
      return res.status(404).json({ success: false, message: 'Product not found.' });
    }

    product.isActive = false;
    await product.save();

    await createAuditLog({
      tenantId,
      eventType: 'product_deleted',
      userId: req.userId,
      userRole: req.user.role,
      action: `Deleted product: ${product.name}`,
      ipAddress: req.ip
    });

    res.json({ success: true, message: 'Product deleted.' });
  } catch (error) {
    res.status(500).json({ success: false, message: 'Server error.' });
  }
});

module.exports = router;
