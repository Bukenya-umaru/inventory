const express = require('express');
const router = express.Router();
const Product = require('../models/Product');
const Purchase = require('../models/Purchase');
const Category = require('../models/Category');
const { createAuditLog } = require('../utils/audit');
const { notifyLowStock } = require('../utils/notifications');
const { authenticate, requireActiveTenant, requirePermission } = require('../middleware/auth');

// Resolves the supplier for a purchase record: validates supplierId against
// the tenant when provided, falling back to the free-text supplier name.
async function resolveSupplier(tenantId, body) {
  if (body.supplierId) {
    const Supplier = require('../models/Supplier');
    const doc = await Supplier.findOne({ _id: body.supplierId, tenantId });
    if (doc) {
      return {
        supplier: doc.name,
        supplierId: doc._id,
        supplierPhone: body.supplierPhone ?? doc.phone ?? undefined,
        supplierEmail: body.supplierEmail ?? doc.email ?? undefined
      };
    }
  }
  return { supplier: body.supplier || undefined, supplierId: undefined, supplierPhone: body.supplierPhone, supplierEmail: body.supplierEmail };
}

router.get('/', authenticate, requireActiveTenant, async (req, res) => {
  try {
    const tenantId = req.user.role === 'developer' ? req.query.tenantId : req.user.tenantId;
    const { category, search, lowStock, purchaseDate, page = 1, limit = 50 } = req.query;

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
    if (purchaseDate) {
      const start = new Date(purchaseDate);
      const end = new Date(start);
      end.setHours(23, 59, 59, 999);
      const purchases = await Purchase.find({
        tenantId,
        status: 'approved',
        purchaseDate: { $gte: start, $lte: end }
      }).select('productId');
      query._id = { $in: purchases.map((purchase) => purchase.productId) };
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

router.post('/', authenticate, requireActiveTenant, requirePermission('create_products'), async (req, res) => {
  try {
    const { name, description, sku, categoryId, costPrice, sellingPrice, currentStock, minimumStock, unit, sellingUnit, unitsPerBox, stockBoxes, boxSellingPrice, boxCostPrice,

      supplier, supplierPhone, supplierEmail, invoiceNumber, paymentMethod, notes, purchaseUnit: reqPurchaseUnit, unitCost: reqUnitCost,

      batchCostPrice, batchSellingPrice } = req.body;

    if (!name || !categoryId || costPrice === undefined || sellingPrice === undefined) {
      return res.status(400).json({ success: false, message: 'Required fields missing.' });
    }

    const tenantId = req.user.role === 'developer' ? req.body.tenantId : req.user.tenantId;

    const category = await Category.findOne({
      _id: categoryId,
      tenantId,
      type: { $in: ['product', null] }
    });
    if (!category) {
      return res.status(400).json({ success: false, message: 'Invalid category.' });
    }

    const normalizedName = name.trim().toLowerCase();
    const existingProduct = await Product.findOne({
      tenantId,
      isActive: true,
      name: { $regex: new RegExp(`^${normalizedName.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}$`, 'i') }
    });

    if (existingProduct) {

      let purchaseUnit = reqPurchaseUnit || (sellingUnit === 'piece' ? 'piece' : 'box');
      if (!['piece', 'box'].includes(purchaseUnit)) purchaseUnit = 'box';

      const qtyToAdd = sellingUnit === 'box'
        ? (stockBoxes || 0)
        : (currentStock || 0);

      const upb = existingProduct.unitsPerBox || 1;

      const differs = (newVal, prevVal) =>
        Math.abs(Number(newVal) - Number(prevVal ?? 0)) >= 0.01;
      let pricesUpdated = false;

      if (batchCostPrice != null) {
        const prevCost = purchaseUnit === 'box'
          ? (existingProduct.boxCostPrice ?? existingProduct.costPrice * upb)
          : existingProduct.costPrice;
        if (differs(batchCostPrice, prevCost)) {
          if (purchaseUnit === 'box') {
            existingProduct.boxCostPrice = batchCostPrice;
            existingProduct.costPrice = Math.round((batchCostPrice / upb) * 100) / 100;
          } else {
            existingProduct.costPrice = batchCostPrice;
            if (upb > 1) {
              existingProduct.boxCostPrice = Math.round(batchCostPrice * upb * 100) / 100;
            }
          }
          pricesUpdated = true;
        }
      }
      if (batchSellingPrice != null) {
        const prevSell = purchaseUnit === 'box'
          ? (existingProduct.boxSellingPrice ?? existingProduct.sellingPrice * upb)
          : existingProduct.sellingPrice;
        if (differs(batchSellingPrice, prevSell)) {
          if (purchaseUnit === 'box') {
            existingProduct.boxSellingPrice = batchSellingPrice;
            existingProduct.sellingPrice = Math.round((batchSellingPrice / upb) * 100) / 100;
          } else {
            existingProduct.sellingPrice = batchSellingPrice;
            if (upb > 1) {
              existingProduct.boxSellingPrice = Math.round(batchSellingPrice * upb * 100) / 100;
            }
          }
          pricesUpdated = true;
        }
      }

      if (qtyToAdd > 0) {
        // Stock is NOT applied here anymore — it is applied only when the
        // pending purchase record is approved by the business owner.
      }

      if (pricesUpdated) {
        existingProduct.priceHistory.push({
          costPrice: existingProduct.costPrice,
          sellingPrice: existingProduct.sellingPrice,
          boxCostPrice: existingProduct.boxCostPrice ?? undefined,
          boxSellingPrice: existingProduct.boxSellingPrice ?? undefined,
          unitsPerBox: existingProduct.unitsPerBox,
          source: 'restock',
          changedBy: req.userId
        });
        try {
          await existingProduct.save();
        } catch (histErr) {
          console.error('Price history error:', histErr);
        }
      }

      const unitCost = reqUnitCost != null
        ? reqUnitCost
        : purchaseUnit === 'box'
          ? (batchCostPrice ?? boxCostPrice ?? existingProduct.boxCostPrice ?? existingProduct.costPrice * upb)
          : (batchCostPrice ?? costPrice ?? existingProduct.costPrice);
      const totalCost = unitCost * (qtyToAdd || 0);

      const resolved = await resolveSupplier(tenantId, req.body);
      let purchase = null;
      if (qtyToAdd > 0 || supplier || resolved.supplierId) {
        purchase = new Purchase({
          tenantId,
          productId: existingProduct._id,
          quantity: qtyToAdd || 0,
          purchaseUnit,
          unitCost,
          unitSellingPrice: batchSellingPrice ?? undefined,
          totalCost,
          supplier: resolved.supplier,
          supplierId: resolved.supplierId,
          supplierPhone: resolved.supplierPhone,
          supplierEmail: resolved.supplierEmail,
          invoiceNumber,
          paymentMethod: paymentMethod || 'cash',
          creditPaid: false,
          notes,
          recordedBy: req.userId,
          status: 'pending'
        });
        await purchase.save();
      }

      const priceChange = pricesUpdated
        ? `buy ${existingProduct.costPrice}, sell ${existingProduct.sellingPrice}`
        : null;        await createAuditLog({
          tenantId,
          eventType: 'stock_merged',
          userId: req.userId,
          userRole: req.user.role,
          action: `Merged stock: ${qtyToAdd}x ${existingProduct.name} (${purchaseUnit}) — pending approval${priceChange ? ` — prices updated (${priceChange})` : ''}`,
          details: { productName: existingProduct.name, quantity: qtyToAdd, purchaseUnit, supplier, merged: true, unitCost, unitSellingPrice: batchSellingPrice ?? null, status: 'pending' },
          ipAddress: req.ip
        });

      return res.status(200).json({
        success: true,
        message: `Product "${existingProduct.name}" already exists. Stock entry pending approval (+${qtyToAdd} ${purchaseUnit}s).`,
        product: existingProduct,
        merged: true,
        pricesUpdated,
        purchase
      });
    }

    // ── No duplicate — create new product ──
    // Opening stock goes through the same approval flow: the product starts
    // at zero and a pending purchase record carries the opening quantity.
    // Stock is applied only when the business owner approves it.
    const initialQtyUnit = sellingUnit === 'box' ? 'box' : 'piece';
    const initialQty = initialQtyUnit === 'box' ? (stockBoxes || 0) : (currentStock || 0);

    const product = new Product({
      name,
      description,
      sku,
      categoryId,
      tenantId,
      costPrice,
      sellingPrice,
      currentStock: 0,
      minimumStock: minimumStock || 5,
      unit: unit || 'piece',
      sellingUnit: sellingUnit || 'piece',
      unitsPerBox: unitsPerBox || 1,
      stockBoxes: 0,
      boxSellingPrice: boxSellingPrice,
      boxCostPrice: boxCostPrice,
      createdBy: req.userId
    });

    await product.save();

    // Seed the price history with the initial prices
    product.priceHistory.push({
      costPrice: product.costPrice,
      sellingPrice: product.sellingPrice,
      boxCostPrice: product.boxCostPrice ?? undefined,
      boxSellingPrice: product.boxSellingPrice ?? undefined,
      unitsPerBox: product.unitsPerBox,
      source: 'created',
      changedBy: req.userId
    });
    // Save again silently — history failures must not fail the request
    try {
      await product.save();
    } catch (histErr) {
      console.error('Price history seed error:', histErr);
    }

    // Pending purchase record for the opening stock (approved later by owner)
    const resolved = await resolveSupplier(tenantId, req.body);
    let purchase = null;
    if (initialQty > 0) {
      const openingUnitCost = initialQtyUnit === 'box'
        ? (boxCostPrice ?? costPrice * (unitsPerBox || 1))
        : costPrice;
      purchase = new Purchase({
        tenantId,
        productId: product._id,
        quantity: initialQty,
        purchaseUnit: initialQtyUnit,
        unitCost: openingUnitCost,
        unitSellingPrice: batchSellingPrice ?? sellingPrice,
        totalCost: openingUnitCost * initialQty,
        supplier: resolved.supplier,
        supplierId: resolved.supplierId,
        supplierPhone: resolved.supplierPhone,
        supplierEmail: resolved.supplierEmail,
        invoiceNumber,
        paymentMethod: paymentMethod || 'cash',
        creditPaid: false,
        notes,
        recordedBy: req.userId,
        status: 'pending'
      });
      try {
        await purchase.save();
      } catch (pErr) {
        console.error('Opening purchase record error:', pErr);
      }
    }

    await createAuditLog({
      tenantId,
      eventType: 'product_created',
      userId: req.userId,
      userRole: req.user.role,
      action: `Created product: ${name}${initialQty > 0 ? ` — opening stock ${initialQty} ${initialQtyUnit}(s) pending approval` : ''}`,
      details: { name, sku, costPrice, sellingPrice, openingQty: initialQty, openingUnit: initialQtyUnit },
      ipAddress: req.ip
    });

    res.status(201).json({ success: true, message: 'Product created.', product, purchase });
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
    const changes = {};
    for (const [field, value] of Object.entries(updates)) {
      if (String(product[field] ?? '') !== String(value ?? '')) {
        changes[field] = { from: product[field] ?? null, to: value };
      }
    }

    // Detect price changes before applying the update so we can record history
    const priceFields = ['costPrice', 'sellingPrice', 'boxCostPrice', 'boxSellingPrice', 'unitsPerBox'];
    const priceChanged = priceFields.some(
      (f) => updates[f] !== undefined && Number(updates[f]) !== Number(product[f] ?? 0)
    );

    Object.assign(product, updates);
    await product.save();

    // Notification: warn the whole business (admin + employees) if the updated
    // product is now at/below its minimum stock level.
    await notifyLowStock(product, { userId: req.userId, userRole: req.user.role }, { reason: 'product-edit' });

    if (priceChanged) {
      product.priceHistory.push({
        costPrice: product.costPrice,
        sellingPrice: product.sellingPrice,
        boxCostPrice: product.boxCostPrice ?? undefined,
        boxSellingPrice: product.boxSellingPrice ?? undefined,
        unitsPerBox: product.unitsPerBox,
        source: 'edit',
        changedBy: req.userId
      });
      try {
        await product.save();
      } catch (histErr) {
        console.error('Price history error:', histErr);
      }
    }

    await createAuditLog({
      tenantId,
      eventType: 'product_updated',
      userId: req.userId,
      userRole: req.user.role,
      action: `Updated product: ${product.name}`,
      details: { productId: product._id, changes },
      ipAddress: req.ip,
      userAgent: req.headers['user-agent']
    });

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