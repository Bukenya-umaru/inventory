const express = require('express');
const router = express.Router();
const Purchase = require('../models/Purchase');
const Product = require('../models/Product');
const { createAuditLog } = require('../utils/audit');
const { authenticate, requireActiveTenant, requirePermission } = require('../middleware/auth');

// ── GET /api/purchases ─────────────────────────────────────────────
// Returns all stock records (pending + approved) for the History section.
router.get('/', authenticate, requireActiveTenant, async (req, res) => {
  try {
    const tenantId = req.user.role === 'developer' ? req.query.tenantId : req.user.tenantId;
    const { page = 1, limit = 100, startDate, endDate, status, paymentMethod, creditPaid } = req.query;

    const query = { tenantId };
    if (status === 'pending' || status === 'approved') query.status = status;
    if (paymentMethod === 'credit') query.paymentMethod = 'credit';
    if (creditPaid === 'true') query.creditPaid = true;
    if (creditPaid === 'false') query.creditPaid = { $in: [false, null] };
    if (startDate || endDate) {
      query.purchaseDate = {};
      if (startDate) query.purchaseDate.$gte = new Date(startDate);
      if (endDate) query.purchaseDate.$lte = new Date(endDate);
    }
    const total = await Purchase.countDocuments(query);
    const purchases = await Purchase.find(query)
      .populate('productId', 'name sku')
      .populate('recordedBy', 'name')
      .populate('approvedBy', 'name')
      .populate('supplierId', 'name phone email')
      .sort({ purchaseDate: -1 })
      .skip((page - 1) * limit)
      .limit(parseInt(limit));

    res.json({
      success: true,
      purchases,
      pagination: { total, page: parseInt(page), limit: parseInt(limit), pages: Math.ceil(total / limit) }
    });
  } catch (error) {
    console.error('List purchases error:', error);
    res.status(500).json({ success: false, message: 'Server error.' });
  }
});

// ── POST /api/purchases ────────────────────────────────────────────
// Records a stock entry as PENDING. Stock is NOT applied to the product
// here — it is applied only when the record is approved (owner action),
// so the owner sees the record and can have it corrected before locking.
router.post('/', authenticate, requireActiveTenant, requirePermission('create_products'), async (req, res) => {
  try {
    const { productId, quantity, purchaseUnit: reqPurchaseUnit, unitCost, unitSellingPrice, supplier, supplierPhone, supplierEmail, invoiceNumber, paymentMethod, notes } = req.body;
    const normalizedPaymentMethod = paymentMethod || 'cash';

    if (!productId || !quantity || quantity < 1) {
      return res.status(400).json({ success: false, message: 'Product and a quantity of at least 1 are required.' });
    }

    const tenantId = req.user.role === 'developer' ? req.body.tenantId : req.user.tenantId;

    const product = await Product.findOne({ _id: productId, tenantId });
    if (!product) {
      return res.status(404).json({ success: false, message: 'Product not found.' });
    }

    let purchaseUnit = reqPurchaseUnit || 'box';
    if (!['piece', 'box'].includes(purchaseUnit)) purchaseUnit = 'box';

    const cost = unitCost != null ? unitCost : (purchaseUnit === 'box' ? (product.boxCostPrice || product.costPrice * (product.unitsPerBox || 1)) : product.costPrice);
    const totalCost = cost * quantity;

    const purchase = new Purchase({
      tenantId,
      productId,
      quantity,
      purchaseUnit,
      unitCost: cost,
      unitSellingPrice: unitSellingPrice != null ? unitSellingPrice : undefined,
      totalCost,
      supplier,
      supplierPhone,
      supplierEmail,
      invoiceNumber,
      paymentMethod: normalizedPaymentMethod,
      creditPaid: false,
      notes,
      recordedBy: req.userId,
      status: 'pending'
    });
    await purchase.save();

    await createAuditLog({
      tenantId,
      eventType: 'purchase_recorded',
      userId: req.userId,
      userRole: req.user.role,
      action: `Recorded pending stock entry: ${quantity}x ${product.name} (${purchaseUnit}) — awaiting approval`,
      details: { productName: product.name, quantity, purchaseUnit, unitCost: cost, totalCost, supplier, supplierPhone, supplierEmail, invoiceNumber, paymentMethod, status: 'pending' },
      ipAddress: req.ip
    });

    res.status(201).json({
      success: true,
      message: 'Stock entry recorded — pending approval.',
      purchase
    });
  } catch (error) {
    console.error('Record purchase error:', error);
    res.status(500).json({ success: false, message: 'Server error.' });
  }
});

// ── PUT /api/purchases/:id ─────────────────────────────────────────
// Lets the user who added stock fix mistakes BEFORE the business owner
// approves the record. Every change is stored in editHistory for the
// owner to review. Approved records are locked.
router.put('/:id', authenticate, requireActiveTenant, requirePermission('create_products'), async (req, res) => {
  try {
    const tenantId = req.user.role === 'developer' ? req.body.tenantId : req.user.tenantId;
    const purchase = await Purchase.findOne({ _id: req.params.id, tenantId });

    if (!purchase) {
      return res.status(404).json({ success: false, message: 'Purchase record not found.' });
    }
    if (purchase.status !== 'pending') {
      return res.status(400).json({ success: false, message: 'This record has been approved by the business owner and can no longer be edited.' });
    }
    // Only the creator (or admin/developer) may edit a pending record.
    const isOwnerOrAdmin = ['admin', 'developer'].includes(req.user.role) || purchase.recordedBy.toString() === req.userId.toString();
    if (!isOwnerOrAdmin) {
      return res.status(403).json({ success: false, message: 'You can only edit records you added.' });
    }

    const editableFields = ['quantity', 'purchaseUnit', 'unitCost', 'unitSellingPrice', 'supplier', 'supplierPhone', 'supplierEmail', 'invoiceNumber', 'paymentMethod', 'notes'];
    const changes = {};

    // Capture before/after for the audit trail
    for (const field of editableFields) {
      if (req.body[field] !== undefined) {
        const before = purchase[field] ?? null;
        const after = req.body[field];
        if (String(before ?? '') !== String(after ?? '')) {
          changes[field] = { from: before, to: after };
        }
      }
    }
    if (!Object.keys(changes).length) {
      return res.status(400).json({ success: false, message: 'No changes detected.' });
    }

    // Validate unit transition
    if (changes.purchaseUnit) {
      const newUnit = req.body.purchaseUnit;
      if (!['piece', 'box'].includes(newUnit)) {
        return res.status(400).json({ success: false, message: 'purchaseUnit must be "piece" or "box".' });
      }
    }

    // Apply edits
    if (req.body.quantity !== undefined) {
      const qty = Number(req.body.quantity);
      if (!Number.isFinite(qty) || qty < 1) {
        return res.status(400).json({ success: false, message: 'Quantity must be at least 1.' });
      }
      purchase.quantity = qty;
    }
    if (req.body.purchaseUnit !== undefined) purchase.purchaseUnit = req.body.purchaseUnit;
    if (req.body.unitCost !== undefined) {
      const cost = Number(req.body.unitCost);
      if (!Number.isFinite(cost) || cost < 0) {
        return res.status(400).json({ success: false, message: 'Unit cost must be 0 or more.' });
      }
      purchase.unitCost = cost;
    }
    if (req.body.unitSellingPrice !== undefined) purchase.unitSellingPrice = req.body.unitSellingPrice;
    if (req.body.supplier !== undefined) purchase.supplier = req.body.supplier;
    if (req.body.supplierId !== undefined) {
      // Accept a Supplier id (validated against the tenant) or null to clear.
      if (req.body.supplierId) {
        const Supplier = require('../models/Supplier');
        const supplierDoc = await Supplier.findOne({ _id: req.body.supplierId, tenantId });
        if (!supplierDoc) {
          return res.status(400).json({ success: false, message: 'Supplier not found.' });
        }
        purchase.supplierId = supplierDoc._id;
        // Keep the text snapshot in sync with the selected supplier.
        purchase.supplier = supplierDoc.name;
        purchase.supplierPhone = supplierDoc.phone || purchase.supplierPhone;
        purchase.supplierEmail = supplierDoc.email || purchase.supplierEmail;
      } else {
        purchase.supplierId = null;
      }
    }
    if (req.body.supplierPhone !== undefined) purchase.supplierPhone = req.body.supplierPhone;
    if (req.body.supplierEmail !== undefined) purchase.supplierEmail = req.body.supplierEmail;
    if (req.body.invoiceNumber !== undefined) purchase.invoiceNumber = req.body.invoiceNumber;
    if (req.body.paymentMethod !== undefined) {
      purchase.paymentMethod = req.body.paymentMethod;
      if (purchase.paymentMethod !== 'credit') {
        purchase.creditPaid = false;
        purchase.creditPaidAt = null;
        purchase.creditPaidBy = null;
      }
    }
    if (req.body.notes !== undefined) purchase.notes = req.body.notes;

    // Recompute totalCost after quantity/cost edits
    purchase.totalCost = purchase.unitCost * purchase.quantity;

    // Keep the before/after trail for the owner to review
    purchase.editHistory.push({
      editedBy: req.userId,
      editedAt: new Date(),
      changes
    });
    await purchase.save();

    const product = await Product.findById(purchase.productId).select('name');
    await createAuditLog({
      tenantId,
      eventType: 'purchase_edited',
      userId: req.userId,
      userRole: req.user.role,
      action: `Edited pending stock record for ${product ? product.name : 'product'}: ${Object.keys(changes).join(', ')}`,
      details: { purchaseId: purchase._id, changes },
      ipAddress: req.ip
    });

    res.json({
      success: true,
      message: 'Record updated.',
      purchase
    });
  } catch (error) {
    console.error('Edit purchase error:', error);
    res.status(500).json({ success: false, message: 'Server error.' });
  }
});

// ── POST /api/purchases/:id/approve ────────────────────────────────
// Business-owner action: locks the record and applies the stock to the
// product. Records already approved are a no-op.
router.post('/:id/approve', authenticate, requireActiveTenant, requirePermission('record_purchases'), async (req, res) => {
  try {
    const tenantId = req.user.role === 'developer' ? req.body.tenantId : req.user.tenantId;
    const purchase = await Purchase.findOne({ _id: req.params.id, tenantId });

    if (!purchase) {
      return res.status(404).json({ success: false, message: 'Purchase record not found.' });
    }
    if (purchase.status === 'approved') {
      return res.status(400).json({ success: false, message: 'This record is already approved.' });
    }

    const product = await Product.findOne({ _id: purchase.productId, tenantId });
    if (!product) {
      return res.status(404).json({ success: false, message: 'Product not found.' });
    }

    // Apply stock now that the owner has confirmed the entry.
    if (purchase.purchaseUnit === 'box') {
      product.stockBoxes += purchase.quantity;
    } else {
      product.currentStock += purchase.quantity;
    }
    // Restocked above minimum — reset the alert flag so a future drop
    // triggers a fresh low-stock notification.
    if ((product.currentStock || 0) + (product.stockBoxes || 0) * (product.unitsPerBox || 1) > (product.minimumStock ?? 0)) {
      product.lowStockAlerted = false;
    }
    await product.save();

    purchase.status = 'approved';
    purchase.approvedBy = req.userId;
    purchase.approvedAt = new Date();
    await purchase.save();

    await createAuditLog({
      tenantId,
      eventType: 'purchase_approved',
      userId: req.userId,
      userRole: req.user.role,
      action: `Approved stock entry: ${purchase.quantity}x ${product.name} (${purchase.purchaseUnit}) — stock applied`,
      details: { purchaseId: purchase._id, productName: product.name, quantity: purchase.quantity, purchaseUnit: purchase.purchaseUnit, totalCost: purchase.totalCost },
      ipAddress: req.ip
    });

    res.json({
      success: true,
      message: `Approved — ${purchase.quantity} ${purchase.purchaseUnit === 'box' ? 'box(es)' : 'piece(s)'} added to ${product.name}.`,
      purchase
    });
  } catch (error) {
    console.error('Approve purchase error:', error);
    res.status(500).json({ success: false, message: 'Server error.' });
  }
});

// ── POST /api/purchases/:id/mark-paid ─────────────────────────────
// Marks a credit stock purchase as fully paid.
router.post('/:id/mark-paid', authenticate, requireActiveTenant, requirePermission('approve_credits'), async (req, res) => {
  try {
    const tenantId = req.user.role === 'developer' ? req.body.tenantId : req.user.tenantId;
    const purchase = await Purchase.findOne({
      _id: req.params.id,
      tenantId,
      paymentMethod: 'credit',
      status: 'approved'
    });
    if (!purchase) {
      return res.status(404).json({ success: false, message: 'Credit purchase not found.' });
    }
    if (purchase.creditPaid) {
      return res.status(400).json({ success: false, message: 'This credit has already been marked as paid.' });
    }

    purchase.creditPaid = true;
    purchase.creditPaidAt = new Date();
    purchase.creditPaidBy = req.userId;
    await purchase.save();

    await createAuditLog({
      tenantId,
      eventType: 'credit_paid',
      userId: req.userId,
      userRole: req.user.role,
      action: `Marked credit purchase as fully paid: ${purchase.totalCost}`,
      details: { purchaseId: purchase._id, totalCost: purchase.totalCost, creditPaid: true },
      ipAddress: req.ip
    });

    res.json({ success: true, message: 'Credit marked as fully paid.', purchase });
  } catch (error) {
    console.error('Mark credit paid error:', error);
    res.status(500).json({ success: false, message: 'Server error.' });
  }
});

module.exports = router;
