const express = require('express');
const router = express.Router();
const Category = require('../models/Category');
const { createAuditLog } = require('../utils/audit');
const { authenticate, requireActiveTenant, requirePermission } = require('../middleware/auth');

router.get('/', authenticate, requireActiveTenant, async (req, res) => {
  try {
    const tenantId = req.user.role === 'developer' ? req.query.tenantId : req.user.tenantId;
    const categories = await Category.find({ tenantId, isActive: true }).sort({ name: 1 });
    res.json({ success: true, categories });
  } catch (error) {
    res.status(500).json({ success: false, message: 'Server error.' });
  }
});

router.post('/', authenticate, requireActiveTenant, requirePermission('manage_categories'), async (req, res) => {
  try {
    const { name, description } = req.body;
    if (!name) {
      return res.status(400).json({ success: false, message: 'Category name required.' });
    }

    const tenantId = req.user.role === 'developer' ? req.body.tenantId : req.user.tenantId;

    const existing = await Category.findOne({ name, tenantId });
    if (existing) {
      return res.status(400).json({ success: false, message: 'Category already exists.' });
    }

    const category = new Category({
      name,
      description,
      tenantId,
      createdBy: req.userId
    });
    await category.save();

    await createAuditLog({
      tenantId,
      eventType: 'category_created',
      userId: req.userId,
      userRole: req.user.role,
      action: `Created category: ${name}`,
      ipAddress: req.ip
    });

    res.status(201).json({ success: true, message: 'Category created.', category });
  } catch (error) {
    res.status(500).json({ success: false, message: 'Server error.' });
  }
});

router.put('/:id', authenticate, requireActiveTenant, requirePermission('manage_categories'), async (req, res) => {
  try {
    const tenantId = req.user.role === 'developer' ? req.body.tenantId : req.user.tenantId;
    const category = await Category.findOne({ _id: req.params.id, tenantId });
    if (!category) {
      return res.status(404).json({ success: false, message: 'Category not found.' });
    }

    category.name = req.body.name || category.name;
    category.description = req.body.description || category.description;
    await category.save();

    res.json({ success: true, message: 'Category updated.', category });
  } catch (error) {
    res.status(500).json({ success: false, message: 'Server error.' });
  }
});

router.delete('/:id', authenticate, requireActiveTenant, requirePermission('manage_categories'), async (req, res) => {
  try {
    const tenantId = req.user.role === 'developer' ? req.query.tenantId : req.user.tenantId;
    const category = await Category.findOne({ _id: req.params.id, tenantId });
    if (!category) {
      return res.status(404).json({ success: false, message: 'Category not found.' });
    }

    category.isActive = false;
    await category.save();

    res.json({ success: true, message: 'Category deleted.' });
  } catch (error) {
    res.status(500).json({ success: false, message: 'Server error.' });
  }
});

module.exports = router;