const express = require('express');
const router = express.Router();
const bcrypt = require('bcryptjs');
const User = require('../models/User');
const Tenant = require('../models/Tenant');
const { encryptPassword } = require('../utils/encryption');
const { createAuditLog } = require('../utils/audit');
const { authenticate, requireRole } = require('../middleware/auth');

// GET /api/users - List users based on role
router.get('/', authenticate, async (req, res) => {
  try {
    const { role, page = 1, limit = 20, search } = req.query;
    let query = {};

    if (req.user.role === 'developer') {
      // Developer sees all users across all businesses
      if (role) query.role = role;
    } else if (req.user.role === 'admin') {
      // Admin sees only their business employees
      query.tenantId = req.user.tenantId;
      query.role = 'employee';
    } else {
      // Employee can only see themselves
      return res.json({
        success: true,
        users: [{
          id: req.user._id,
          name: req.user.name,
          email: req.user.email,
          role: req.user.role,
          permissions: req.user.permissions
        }],
        pagination: { total: 1, page: 1, limit: 1, pages: 1 }
      });
    }

    if (search) {
      query.$or = [
        { name: { $regex: search, $options: 'i' } },
        { email: { $regex: search, $options: 'i' } }
      ];
    }

    query.isActive = true;

    const total = await User.countDocuments(query);
    const users = await User.find(query)
      .select('-encryptedPassword -passwordIV -passwordHash')
      .populate('tenantId', 'businessName')
      .sort({ createdAt: -1 })
      .skip((page - 1) * limit)
      .limit(parseInt(limit));

    res.json({
      success: true,
      users,
      pagination: { total, page: parseInt(page), limit: parseInt(limit), pages: Math.ceil(total / limit) }
    });
  } catch (error) {
    res.status(500).json({ success: false, message: 'Server error.' });
  }
});

// POST /api/users - Create employee (Admin or Developer)
router.post('/', authenticate, async (req, res) => {
  try {
    const { name, email, password, permissions, department, position } = req.body;

    if (!name || !email || !password) {
      return res.status(400).json({ success: false, message: 'Name, email, and password required.' });
    }

    // Check email uniqueness
    const existing = await User.findOne({ email: email.toLowerCase() });
    if (existing) {
      return res.status(400).json({ success: false, message: 'Email already registered.' });
    }

    let tenantId, createdByRole, creationReason, createdBy;

    if (req.user.role === 'developer') {
      // Developer creating backup employee
      tenantId = req.body.tenantId;
      if (!tenantId) {
        return res.status(400).json({ success: false, message: 'Business selection required.' });
      }
      createdByRole = 'developer';
      creationReason = 'backup';
      createdBy = req.userId;
    } else if (req.user.role === 'admin') {
      // Admin creating primary employee
      tenantId = req.user.tenantId;
      createdByRole = 'admin';
      creationReason = 'primary';
      createdBy = req.userId;
    } else {
      return res.status(403).json({ success: false, message: 'Not authorized to create users.' });
    }

    // Check employee limit
    const tenant = await Tenant.findById(tenantId);
    if (!tenant) {
      return res.status(404).json({ success: false, message: 'Business not found.' });
    }
    const currentEmployees = await User.countDocuments({ tenantId, role: 'employee', isActive: true });
    if (currentEmployees >= tenant.maxEmployees) {
      return res.status(400).json({ success: false, message: 'Employee limit reached.' });
    }

    // Default permissions for admin-created employees
    const defaultPermissions = permissions || [
      'manage_categories', 'record_sales', 'record_purchases', 'record_damages',
      'view_inventory', 'view_transactions', 'view_reports'
    ];

    const { encryptedPassword, iv } = encryptPassword(password);
    const passwordHash = await bcrypt.hash(password, 12);

    const employeeId = `EMP-${Date.now().toString(36).toUpperCase()}`;

    const user = new User({
      name,
      email: email.toLowerCase(),
      encryptedPassword,
      passwordIV: iv,
      passwordHash,
      role: 'employee',
      tenantId,
      createdBy,
      createdByRole,
      creationReason,
      backupReason: req.body.backupReason,
      employeeId,
      department,
      position,
      permissions: defaultPermissions
    });

    await user.save();

    await createAuditLog({
      tenantId,
      eventType: creationReason === 'backup' ? 'employee_created_backup' : 'employee_created_primary',
      userId: req.userId,
      userRole: req.user.role,
      action: `Created employee: ${name}`,
      details: { email, employeeId, createdByRole },
      ipAddress: req.ip,
      userAgent: req.headers['user-agent']
    });

    res.status(201).json({
      success: true,
      message: 'Employee created successfully.',
      user: {
        id: user._id,
        name: user.name,
        email: user.email,
        employeeId: user.employeeId,
        role: user.role,
        permissions: user.permissions
      }
    });
  } catch (error) {
    console.error('Create user error:', error);
    res.status(500).json({ success: false, message: 'Server error.' });
  }
});

// PUT /api/users/:id/permissions - Update employee permissions (Admin)
router.put('/:id/permissions', authenticate, requireRole('admin'), async (req, res) => {
  try {
    const { permissions } = req.body;
    const user = await User.findOne({ _id: req.params.id, tenantId: req.user.tenantId, role: 'employee' });

    if (!user) {
      return res.status(404).json({ success: false, message: 'Employee not found.' });
    }

    user.permissions = permissions;
    await user.save();

    await createAuditLog({
      tenantId: req.user.tenantId,
      eventType: 'employee_permissions_updated',
      userId: req.userId,
      userRole: 'admin',
      action: `Updated permissions for: ${user.name}`,
      details: { permissions },
      ipAddress: req.ip,
      userAgent: req.headers['user-agent']
    });

    res.json({ success: true, message: 'Permissions updated.', user: { id: user._id, permissions: user.permissions } });
  } catch (error) {
    res.status(500).json({ success: false, message: 'Server error.' });
  }
});

// DELETE /api/users/:id - Delete employee (Admin request or Developer direct)
router.delete('/:id', authenticate, async (req, res) => {
  try {
    const user = await User.findById(req.params.id);
    if (!user) {
      return res.status(404).json({ success: false, message: 'User not found.' });
    }

    if (req.user.role === 'admin') {
      // Admin requests deletion - mark for developer review
      if (user.tenantId.toString() !== req.user.tenantId.toString()) {
        return res.status(403).json({ success: false, message: 'Access denied.' });
      }
      user.isActive = false;
      user.deletedAt = new Date();
      user.deletedBy = req.userId;
      user.deletionReason = req.body.reason || 'Admin requested deletion';
      await user.save();
    } else if (req.user.role === 'developer') {
      // Developer can directly delete
      user.isActive = false;
      user.deletedAt = new Date();
      user.deletedBy = req.userId;
      user.deletionReason = req.body.reason || 'Developer deletion';
      await user.save();
    } else {
      return res.status(403).json({ success: false, message: 'Not authorized.' });
    }

    await createAuditLog({
      tenantId: user.tenantId,
      eventType: 'employee_deleted',
      severity: 'warning',
      userId: req.userId,
      userRole: req.user.role,
      action: `Deleted employee: ${user.name}`,
      details: { reason: user.deletionReason },
      ipAddress: req.ip,
      userAgent: req.headers['user-agent']
    });

    res.json({ success: true, message: 'Employee deleted.' });
  } catch (error) {
    res.status(500).json({ success: false, message: 'Server error.' });
  }
});

// POST /api/users/admin - Developer: create admin accounts
router.post('/admin', authenticate, requireRole('developer'), async (req, res) => {
  try {
    const { name, email, password, tenantId } = req.body;

    if (!name || !email || !password || !tenantId) {
      return res.status(400).json({ success: false, message: 'All fields required.' });
    }

    const existing = await User.findOne({ email: email.toLowerCase() });
    if (existing) {
      return res.status(400).json({ success: false, message: 'Email already registered.' });
    }

    const { encryptedPassword, iv } = encryptPassword(password);
    const passwordHash = await bcrypt.hash(password, 12);

    const admin = new User({
      name,
      email: email.toLowerCase(),
      encryptedPassword,
      passwordIV: iv,
      passwordHash,
      role: 'admin',
      tenantId,
      createdBy: req.userId,
      createdByRole: 'developer',
      creationReason: 'primary',
      permissions: [
        'manage_categories', 'create_products', 'edit_products', 'delete_products',
        'record_sales', 'record_purchases', 'record_damages', 'view_inventory',
        'view_transactions', 'view_profits', 'adjust_inventory', 'view_reports'
      ]
    });

    await admin.save();

    await createAuditLog({
      tenantId,
      eventType: 'admin_created',
      userId: req.userId,
      userRole: 'developer',
      action: `Created admin: ${name}`,
      details: { email },
      ipAddress: req.ip,
      userAgent: req.headers['user-agent']
    });

    res.status(201).json({
      success: true,
      message: 'Admin account created.',
      user: { id: admin._id, name: admin.name, email: admin.email, role: admin.role }
    });
  } catch (error) {
    res.status(500).json({ success: false, message: 'Server error.' });
  }
});

module.exports = router;
