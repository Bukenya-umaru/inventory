const express = require('express');
const router = express.Router();
const mongoose = require('mongoose');
const Supplier = require('../models/Supplier');
const Purchase = require('../models/Purchase');
const { createAuditLog } = require('../utils/audit');
const { authenticate, requireActiveTenant, requirePermission } = require('../middleware/auth');

// ── GET /api/suppliers ─────────────────────────────────────────────
// Lists all active suppliers for the business. Optional ?search= filters
// by name/phone/email — used by the supplier picker in product forms.
router.get('/', authenticate, requireActiveTenant, async (req, res) => {
  try {
    const tenantId = req.user.role === 'developer' ? req.query.tenantId : req.user.tenantId;
    const { search } = req.query;

    const query = { tenantId, isActive: true };
    if (search) {
      const escaped = String(search).replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
      query.$or = [
        { name: { $regex: escaped, $options: 'i' } },
        { phone: { $regex: escaped, $options: 'i' } },
        { email: { $regex: escaped, $options: 'i' } }
      ];
    }

    const suppliers = await Supplier.find(query).sort({ name: 1 });

    // Total approved spend per supplier so the Companies section can show
    // "supplied X times / total cost" next to each supplier.
    const stats = await Purchase.aggregate([
      { $match: { tenantId: new mongoose.Types.ObjectId(tenantId), status: 'approved' } },
      { $group: { _id: '$supplierId', count: { $sum: 1 }, totalCost: { $sum: '$totalCost' } } }
    ]);
    const statsByName = await Purchase.aggregate([
      { $match: { tenantId: new mongoose.Types.ObjectId(tenantId), status: 'approved' } },
      { $group: { _id: '$supplier', count: { $sum: 1 }, totalCost: { $sum: '$totalCost' } } }
    ]);
    const byId = new Map(stats.map((s) => [String(s._id), s]));
    const byName = new Map(statsByName.filter((s) => s._id).map((s) => [s._id, s]));

    const enriched = suppliers.map((s) => {
      const stat = byId.get(String(s._id)) || byName.get(s.name) || { count: 0, totalCost: 0 };
      return {
        ...s.toObject(),
        purchaseCount: stat.count || 0,
        totalSpent: stat.totalCost || 0
      };
    });

    res.json({ success: true, suppliers: enriched });
  } catch (error) {
    console.error('List suppliers error:', error);
    res.status(500).json({ success: false, message: 'Server error.' });
  }
});

// ── POST /api/suppliers ────────────────────────────────────────────
router.post('/', authenticate, requireActiveTenant, requirePermission('manage_categories'), async (req, res) => {
  try {
    const { name, contactPerson, phone, email, address, notes } = req.body;
    if (!name || !String(name).trim()) {
      return res.status(400).json({ success: false, message: 'Supplier name required.' });
    }

    const tenantId = req.user.role === 'developer' ? req.body.tenantId : req.user.tenantId;

    const existing = await Supplier.findOne({
      tenantId,
      name: String(name).trim(),
      isActive: true
    });
    if (existing) {
      return res.status(400).json({ success: false, message: 'A supplier with this name already exists.' });
    }

    const supplier = new Supplier({
      tenantId,
      name: String(name).trim(),
      contactPerson,
      phone,
      email,
      address,
      notes,
      createdBy: req.userId
    });
    await supplier.save();

    await createAuditLog({
      tenantId,
      eventType: 'supplier_created',
      userId: req.userId,
      userRole: req.user.role,
      action: `Added supplier: ${supplier.name}`,
      details: { supplierId: supplier._id, name: supplier.name, phone, email },
      ipAddress: req.ip
    });

    res.status(201).json({ success: true, message: 'Supplier added.', supplier });
  } catch (error) {
    console.error('Create supplier error:', error);
    res.status(500).json({ success: false, message: 'Server error.' });
  }
});

// ── PUT /api/suppliers/:id ─────────────────────────────────────────
router.put('/:id', authenticate, requireActiveTenant, requirePermission('manage_categories'), async (req, res) => {
  try {
    const tenantId = req.user.role === 'developer' ? req.body.tenantId : req.user.tenantId;
    const supplier = await Supplier.findOne({ _id: req.params.id, tenantId });
    if (!supplier) {
      return res.status(404).json({ success: false, message: 'Supplier not found.' });
    }

    const { name, contactPerson, phone, email, address, notes } = req.body;
    if (name !== undefined) {
      const trimmed = String(name).trim();
      if (!trimmed) {
        return res.status(400).json({ success: false, message: 'Supplier name required.' });
      }
      const dup = await Supplier.findOne({
        tenantId,
        _id: { $ne: supplier._id },
        name: trimmed,
        isActive: true
      });
      if (dup) {
        return res.status(400).json({ success: false, message: 'A supplier with this name already exists.' });
      }
      supplier.name = trimmed;
    }
    if (contactPerson !== undefined) supplier.contactPerson = contactPerson;
    if (phone !== undefined) supplier.phone = phone;
    if (email !== undefined) supplier.email = email;
    if (address !== undefined) supplier.address = address;
    if (notes !== undefined) supplier.notes = notes;

    await supplier.save();

    await createAuditLog({
      tenantId,
      eventType: 'supplier_updated',
      userId: req.userId,
      userRole: req.user.role,
      action: `Updated supplier: ${supplier.name}`,
      details: { supplierId: supplier._id },
      ipAddress: req.ip
    });

    res.json({ success: true, message: 'Supplier updated.', supplier });
  } catch (error) {
    console.error('Update supplier error:', error);
    res.status(500).json({ success: false, message: 'Server error.' });
  }
});

// ── DELETE /api/suppliers/:id ──────────────────────────────────────
// Soft delete — suppliers stay linked to their purchase history.
router.delete('/:id', authenticate, requireActiveTenant, requirePermission('manage_categories'), async (req, res) => {
  try {
    const tenantId = req.user.role === 'developer' ? req.query.tenantId : req.user.tenantId;
    const supplier = await Supplier.findOne({ _id: req.params.id, tenantId });
    if (!supplier) {
      return res.status(404).json({ success: false, message: 'Supplier not found.' });
    }

    supplier.isActive = false;
    await supplier.save();

    await createAuditLog({
      tenantId,
      eventType: 'supplier_deleted',
      userId: req.userId,
      userRole: req.user.role,
      action: `Deleted supplier: ${supplier.name}`,
      details: { supplierId: supplier._id },
      ipAddress: req.ip
    });

    res.json({ success: true, message: 'Supplier deleted.' });
  } catch (error) {
    console.error('Delete supplier error:', error);
    res.status(500).json({ success: false, message: 'Server error.' });
  }
});

module.exports = router;
