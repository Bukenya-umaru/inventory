const express = require('express');
const router = express.Router();
const bcrypt = require('bcryptjs');
const Tenant = require('../models/Tenant');
const User = require('../models/User');
const Category = require('../models/Category');
const Product = require('../models/Product');
const Sale = require('../models/Sale');
const Purchase = require('../models/Purchase');
const { encryptPassword } = require('../utils/encryption');
const { createAuditLog } = require('../utils/audit');
const { authenticate, requireRole } = require('../middleware/auth');
const upload = require('../middleware/upload');

router.get('/', authenticate, requireRole('developer'), async (req, res) => {
  try {
    const { status, search, page = 1, limit = 20 } = req.query;
    const query = {};
    if (status) query.status = status;
    if (search) {
      query.$or = [
        { businessName: { $regex: search, $options: 'i' } },
        { ownerName: { $regex: search, $options: 'i' } },
        { email: { $regex: search, $options: 'i' } }
      ];
    }

    const total = await Tenant.countDocuments(query);
    const tenants = await Tenant.find(query)
      .sort({ createdAt: -1 })
      .skip((page - 1) * limit)
      .limit(parseInt(limit));

    const tenantsWithCounts = await Promise.all(
      tenants.map(async (t) => {
        const userCount = await User.countDocuments({ tenantId: t._id, isActive: true });
        return { ...t.toObject(), userCount };
      })
    );

    res.json({
      success: true,
      tenants: tenantsWithCounts,
      pagination: { total, page: parseInt(page), limit: parseInt(limit), pages: Math.ceil(total / limit) }
    });
  } catch (error) {
    console.error('Get tenants error:', error);
    res.status(500).json({ success: false, message: 'Server error.' });
  }
});

router.get('/stats', authenticate, requireRole('developer'), async (req, res) => {
  try {
    const totalBusinesses = await Tenant.countDocuments();
    const activeBusinesses = await Tenant.countDocuments({ status: 'active' });
    const suspendedBusinesses = await Tenant.countDocuments({ status: 'suspended' });
    const deletedBusinesses = await Tenant.countDocuments({ status: 'deleted' });
    const totalAdmins = await User.countDocuments({ role: 'admin', isActive: true });
    const totalEmployees = await User.countDocuments({ role: 'employee', isActive: true });
    const totalUsers = totalAdmins + totalEmployees;

    const recentTenants = await Tenant.find().sort({ createdAt: -1 }).limit(5);

    res.json({
      success: true,
      stats: {
        totalBusinesses,
        activeBusinesses,
        suspendedBusinesses,
        deletedBusinesses,
        totalUsers,
        totalAdmins,
        totalEmployees,
        maxBusinesses: 1000,
        recentTenants
      }
    });
  } catch (error) {
    res.status(500).json({ success: false, message: 'Server error.' });
  }
});

router.post('/', authenticate, requireRole('developer'), upload.single('businessLogo'), async (req, res) => {
  try {
    const {
      businessName, businessType, phoneNumber, address, taxId,
      email, ownerName, password, defaultCategories
    } = req.body;

    if (!businessName || !phoneNumber || !email || !ownerName || !password) {
      return res.status(400).json({ success: false, message: 'Required fields missing.' });
    }

    const existingUser = await User.findOne({ email: email.toLowerCase() });
    if (existingUser) {
      return res.status(400).json({ success: false, message: 'Email already registered.' });
    }

    const tenant = new Tenant({
      businessName,
      businessType: businessType || 'Retail',
      businessLogo: req.file ? `/uploads/logos/${req.file.filename}` : null,
      phoneNumber,
      address,
      taxId,
      email: email.toLowerCase(),
      ownerName,
      createdBy: req.userId
    });
    await tenant.save();

    const { encryptedPassword, iv } = encryptPassword(password);
    const passwordHash = await bcrypt.hash(password, 12);

    const adminUser = new User({
      name: ownerName,
      email: email.toLowerCase(),
      encryptedPassword,
      passwordIV: iv,
      passwordHash,
      role: 'admin',
      tenantId: tenant._id,
      createdBy: req.userId,
      createdByRole: 'developer',
      creationReason: 'primary',
      permissions: [
        'manage_categories', 'create_products', 'edit_products', 'delete_products',
        'record_sales', 'record_purchases', 'record_damages', 'view_inventory',
        'view_transactions', 'view_profits', 'adjust_inventory', 'view_reports'
      ]
    });
    await adminUser.save();

    const categories = defaultCategories
      ? JSON.parse(defaultCategories)
      : ['Electronics', 'Clothing', 'Food & Beverage', 'Furniture', 'Books', 'Health & Beauty'];

    for (const catName of categories) {
      const category = new Category({
        name: catName,
        tenantId: tenant._id,
        createdBy: adminUser._id
      });
      await category.save();
    }

    await createAuditLog({
      tenantId: tenant._id,
      eventType: 'business_created',
      userId: req.userId,
      userRole: 'developer',
      action: `Created business: ${businessName}`,
      details: { businessName, email },
      ipAddress: req.ip,
      userAgent: req.headers['user-agent']
    });

    res.status(201).json({
      success: true,
      message: 'Business account created successfully.',
      tenant: {
        id: tenant._id,
        businessName: tenant.businessName,
        businessType: tenant.businessType,
        status: tenant.status,
        createdAt: tenant.createdAt
      }
    });
  } catch (error) {
    console.error('Create tenant error:', error);
    res.status(500).json({ success: false, message: 'Server error.' });
  }
});

router.put('/:id/suspend', authenticate, requireRole('developer'), async (req, res) => {
  try {
    const { reason } = req.body;
    const tenant = await Tenant.findById(req.params.id);
    if (!tenant) {
      return res.status(404).json({ success: false, message: 'Business not found.' });
    }
    if (tenant.status !== 'active') {
      return res.status(400).json({ success: false, message: 'Business is not active.' });
    }

    tenant.status = 'suspended';
    tenant.suspensionReason = reason || 'No reason provided';
    tenant.suspensionDate = new Date();
    await tenant.save();

    await createAuditLog({
      tenantId: tenant._id,
      eventType: 'business_suspended',
      severity: 'warning',
      userId: req.userId,
      userRole: 'developer',
      action: `Suspended business: ${tenant.businessName}`,
      details: { reason },
      ipAddress: req.ip,
      userAgent: req.headers['user-agent']
    });

    res.json({ success: true, message: 'Business suspended.' });
  } catch (error) {
    res.status(500).json({ success: false, message: 'Server error.' });
  }
});

router.put('/:id/reactivate', authenticate, requireRole('developer'), async (req, res) => {
  try {
    const tenant = await Tenant.findById(req.params.id);
    if (!tenant) {
      return res.status(404).json({ success: false, message: 'Business not found.' });
    }
    if (tenant.status !== 'suspended') {
      return res.status(400).json({ success: false, message: 'Business is not suspended.' });
    }

    tenant.status = 'active';
    tenant.reactivationDate = new Date();
    tenant.suspensionReason = undefined;
    tenant.suspensionDate = undefined;
    await tenant.save();

    await createAuditLog({
      tenantId: tenant._id,
      eventType: 'business_reactivated',
      userId: req.userId,
      userRole: 'developer',
      action: `Reactivated business: ${tenant.businessName}`,
      ipAddress: req.ip,
      userAgent: req.headers['user-agent']
    });

    res.json({ success: true, message: 'Business reactivated.' });
  } catch (error) {
    res.status(500).json({ success: false, message: 'Server error.' });
  }
});

router.delete('/:id', authenticate, requireRole('developer'), async (req, res) => {
  try {
    const { confirmation } = req.body;
    if (confirmation !== 'DELETE') {
      return res.status(400).json({ success: false, message: 'Type "DELETE" to confirm.' });
    }

    const tenant = await Tenant.findById(req.params.id);
    if (!tenant) {
      return res.status(404).json({ success: false, message: 'Business not found.' });
    }

    tenant.status = 'deleted';
    tenant.deletionReason = req.body.reason || 'Developer deletion';
    tenant.deletionDate = new Date();
    await tenant.save();

    await User.updateMany({ tenantId: tenant._id }, { isActive: false, deletedAt: new Date(), deletedBy: req.userId });

    await createAuditLog({
      tenantId: tenant._id,
      eventType: 'business_deleted',
      severity: 'critical',
      userId: req.userId,
      userRole: 'developer',
      action: `Deleted business: ${tenant.businessName}`,
      details: { reason: tenant.deletionReason },
      ipAddress: req.ip,
      userAgent: req.headers['user-agent']
    });

    res.json({ success: true, message: 'Business permanently deleted.' });
  } catch (error) {
    res.status(500).json({ success: false, message: 'Server error.' });
  }
});

router.get('/:id/dashboard', authenticate, requireRole('admin'), async (req, res) => {
  try {
    const tenantId = req.user.tenantId;
    if (req.params.id !== tenantId.toString()) {
      return res.status(403).json({ success: false, message: 'Access denied.' });
    }

    const today = new Date();
    today.setHours(0, 0, 0, 0);

    const approvedSalesQuery = { status: { $in: ['approved', null] } };
    const todaySales = await Sale.find({ tenantId, ...approvedSalesQuery, saleDate: { $gte: today } });
    const todayRevenue = todaySales.reduce((sum, s) => sum + s.totalAmount, 0);
    const todayProfit = todaySales.reduce((sum, s) => sum + s.profit, 0);

    const employeeCount = await User.countDocuments({ tenantId, role: 'employee', isActive: true });
    const products = await Product.find({ tenantId, isActive: true });
    const productCount = products.length;
    const lowStockProducts = products.filter(p => p.currentStock <= p.minimumStock).length;

    const monthStart = new Date(today.getFullYear(), today.getMonth(), 1);
    const monthlySales = await Sale.find({ tenantId, ...approvedSalesQuery, saleDate: { $gte: monthStart } });
    const monthlyRevenue = monthlySales.reduce((sum, s) => sum + s.totalAmount, 0);
    const monthlyProfit = monthlySales.reduce((sum, s) => sum + s.profit, 0);

    // Statistics section: selected trend, top products and payment mix.
    const requestedStart = req.query.startDate ? new Date(req.query.startDate) : null;
    const requestedEnd = req.query.endDate ? new Date(req.query.endDate) : null;
    const hasValidRange = requestedStart &&
      requestedEnd &&
      !Number.isNaN(requestedStart.getTime()) &&
      !Number.isNaN(requestedEnd.getTime()) &&
      requestedStart <= requestedEnd;
    const trendStart = hasValidRange ? requestedStart : new Date(today);
    const trendEnd = hasValidRange ? requestedEnd : new Date(today);
    if (!hasValidRange) trendStart.setDate(trendStart.getDate() - 29); // 30 days incl. today
    trendEnd.setHours(23, 59, 59, 999);

    const trendSales = await Sale.find({
      tenantId,
      ...approvedSalesQuery,
      saleDate: { $gte: trendStart, $lte: trendEnd }
    }).select('totalAmount profit saleDate productId quantity paymentMethod');

    const trendMap = new Map();
    const trendDays = Math.max(
      1,
      Math.ceil((trendEnd - trendStart) / (24 * 60 * 60 * 1000)) + 1
    );
    for (let i = 0; i < trendDays; i++) {
      const day = new Date(trendStart);
      day.setDate(day.getDate() + i);
      const key = day.toISOString().slice(0, 10);
      trendMap.set(key, { date: key, revenue: 0, profit: 0, salesCount: 0 });
    }
    const productAgg = new Map();
    const paymentAgg = { cash: 0, card: 0, transfer: 0, credit: 0 };
    for (const s of trendSales) {
      const key = new Date(s.saleDate).toISOString().slice(0, 10);
      const bucket = trendMap.get(key);
      if (bucket) {
        bucket.revenue += s.totalAmount;
        bucket.profit += s.profit;
        bucket.salesCount += 1;
      }
      const pid = s.productId ? s.productId.toString() : 'unknown';
      const entry = productAgg.get(pid) || { productId: pid, quantity: 0, revenue: 0, profit: 0, salesCount: 0 };
      entry.quantity += s.quantity;
      entry.revenue += s.totalAmount;
      entry.profit += s.profit;
      entry.salesCount += 1;
      productAgg.set(pid, entry);
      if (paymentAgg[s.paymentMethod] !== undefined) {
        paymentAgg[s.paymentMethod] += s.totalAmount;
      }
    }

    const productIds = [...productAgg.keys()].filter((id) => id !== 'unknown');
    const productDocs = await Product.find({ _id: { $in: productIds } }).select('name');
    const productNames = new Map(productDocs.map((p) => [p._id.toString(), p.name]));
    const topProducts = [...productAgg.values()]
      .sort((a, b) => b.revenue - a.revenue)
      .slice(0, 5)
      .map((e) => ({ ...e, name: productNames.get(e.productId) || 'Unknown product' }));

    const categoryCount = await Category.countDocuments({ tenantId, isActive: true });
    const totalStockValue = products.reduce((sum, p) => {
      const pieceValue = p.costPrice * p.currentStock;
      const boxValue = (p.boxCostPrice || p.costPrice * (p.unitsPerBox || 1)) * (p.stockBoxes || 0);
      return sum + pieceValue + boxValue;
    }, 0);
    const totalStockUnits = products.reduce((sum, p) =>
      sum + (p.currentStock || 0) + (p.stockBoxes || 0) * (p.unitsPerBox || 1), 0);

    // Stock value grouped by category (for the donut chart).
    const stockByCategoryRaw = new Map();
    for (const p of products) {
      const pieceValue = p.costPrice * p.currentStock;
      const boxValue = (p.boxCostPrice || p.costPrice * (p.unitsPerBox || 1)) * (p.stockBoxes || 0);
      const key = p.categoryId ? p.categoryId.toString() : 'unknown';
      stockByCategoryRaw.set(key, (stockByCategoryRaw.get(key) || 0) + pieceValue + boxValue);
    }
    const categoryDocs = await Category.find({ tenantId }).select('name');
    const categoryNames = new Map(categoryDocs.map((c) => [c._id.toString(), c.name]));
    const stockByCategory = [...stockByCategoryRaw.entries()]
      .map(([id, value]) => ({ name: categoryNames.get(id) || 'Uncategorized', value }))
      .sort((a, b) => b.value - a.value);

    // Low-stock alerts: products at/below their minimum, least stock first.
    const lowStockItems = products
      .filter((p) => p.currentStock <= p.minimumStock)
      .sort((a, b) => a.currentStock - b.currentStock)
      .slice(0, 5)
      .map((p) => ({
        name: p.name,
        sku: p.sku || '-',
        stock: p.currentStock
      }));

    // Recent transactions: latest sales + approved purchases merged.
    const recentSales = await Sale.find({ tenantId, ...approvedSalesQuery })
      .sort({ saleDate: -1 })
      .limit(6)
      .select('totalAmount customerName saleDate');
    const recentPurchases = await Purchase.find({ tenantId, status: 'approved' })
      .sort({ purchaseDate: -1 })
      .limit(6)
      .select('totalCost supplier invoiceNumber purchaseDate');
    const recentTransactions = [
      ...recentSales.map((s) => ({
        date: s.saleDate,
        type: 'Sale',
        reference: `SO-${s._id.toString().slice(-5).toUpperCase()}`,
        party: s.customerName || 'Walk-in customer',
        amount: s.totalAmount,
        status: 'Completed'
      })),
      ...recentPurchases.map((p) => ({
        date: p.purchaseDate,
        type: 'Purchase',
        reference: p.invoiceNumber || `PO-${p._id.toString().slice(-5).toUpperCase()}`,
        party: p.supplier || 'Supplier',
        amount: p.totalCost,
        status: 'Completed'
      }))
    ]
      .sort((a, b) => new Date(b.date) - new Date(a.date))
      .slice(0, 6);

    res.json({
      success: true,
      dashboard: {
        today: { revenue: todayRevenue, profit: todayProfit, salesCount: todaySales.length },
        monthly: { revenue: monthlyRevenue, profit: monthlyProfit, salesCount: monthlySales.length },
        employeeCount,
        productCount,
        lowStockProducts,
        lowStockCount: lowStockProducts,
        categoryCount,
        totalStockValue,
        totalStockUnits,
        trend: [...trendMap.values()],
        topProducts,
        paymentBreakdown: paymentAgg,
        stockByCategory,
        lowStockItems,
        recentTransactions
      }
    });
  } catch (error) {
    res.status(500).json({ success: false, message: 'Server error.' });
  }
});


router.put('/:id/branding', authenticate, requireRole('developer'), upload.single('businessLogo'), async (req, res) => {
  try {
    const tenant = await Tenant.findById(req.params.id);
    if (!tenant) {
      return res.status(404).json({ success: false, message: 'Business not found.' });
    }

    const { businessName, phoneNumber, address } = req.body;
    if (businessName) tenant.businessName = businessName;
    if (phoneNumber) tenant.phoneNumber = phoneNumber;
    if (address) tenant.address = address;
    if (req.file) tenant.businessLogo = `/uploads/logos/${req.file.filename}`;

    await tenant.save();
    res.json({ success: true, message: 'Branding updated.', tenant });
  } catch (error) {
    res.status(500).json({ success: false, message: 'Server error.' });
  }
});

router.put('/:id', authenticate, requireRole('developer'), upload.single('businessLogo'), async (req, res) => {
  try {
    const tenant = await Tenant.findById(req.params.id);
    if (!tenant) {
      return res.status(404).json({ success: false, message: 'Business not found.' });
    }

    const editableFields = ['businessName', 'businessType', 'phoneNumber', 'address', 'taxId', 'email', 'ownerName'];
    const changes = {};
    for (const field of editableFields) {
      if (req.body[field] !== undefined && String(tenant[field] ?? '') !== String(req.body[field] ?? '')) {
        changes[field] = { from: tenant[field] ?? null, to: req.body[field] };
        tenant[field] = req.body[field];
      }
    }
    if (req.body.email !== undefined) tenant.email = String(req.body.email).trim().toLowerCase();
    if (req.file) {
      changes.businessLogo = { from: tenant.businessLogo ?? null, to: `/uploads/logos/${req.file.filename}` };
      tenant.businessLogo = `/uploads/logos/${req.file.filename}`;
    }
    if (!Object.keys(changes).length) {
      return res.status(400).json({ success: false, message: 'No changes detected.' });
    }

    await tenant.save();
    await createAuditLog({
      tenantId: tenant._id,
      eventType: 'business_updated',
      userId: req.userId,
      userRole: 'developer',
      action: `Updated business: ${tenant.businessName}`,
      details: { changes },
      ipAddress: req.ip,
      userAgent: req.headers['user-agent']
    });
    res.json({ success: true, message: 'Business updated.', tenant });
  } catch (error) {
    console.error('Update tenant error:', error);
    res.status(500).json({ success: false, message: 'Server error.' });
  }
});

module.exports = router;