const express = require('express');
const router = express.Router();
const bcrypt = require('bcryptjs');
const User = require('../models/User');
const Tenant = require('../models/Tenant');
const { encryptPassword } = require('../utils/encryption');
const { createAuditLog } = require('../utils/audit');
const { authenticate, requireRole } = require('../middleware/auth');

router.get('/', authenticate, async (req, res) => {
  try {
    const { role, page = 1, limit = 20, search } = req.query;
    let query = {};

    if (req.user.role === 'developer') {

      if (role) query.role = role;
    } else if (req.user.role === 'admin') {

      query.tenantId = req.user.tenantId;
      query.role = 'employee';
    } else {

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

router.post('/', authenticate, async (req, res) => {
  try {
    const { name, email, password, permissions, department, position } = req.body;

    if (!name || !email || !password) {
      return res.status(400).json({ success: false, message: 'Name, email, and password required.' });
    }

    const existing = await User.findOne({ email: email.toLowerCase() });
    if (existing) {
      return res.status(400).json({ success: false, message: 'Email already registered.' });
    }

    let tenantId, createdByRole, creationReason, createdBy;

    if (req.user.role === 'developer') {

      tenantId = req.body.tenantId;
      if (!tenantId) {
        return res.status(400).json({ success: false, message: 'Business selection required.' });
      }
      createdByRole = 'developer';
      creationReason = 'backup';
      createdBy = req.userId;
    } else if (req.user.role === 'admin') {

      tenantId = req.user.tenantId;
      createdByRole = 'admin';
      creationReason = 'primary';
      createdBy = req.userId;
    } else {
      return res.status(403).json({ success: false, message: 'Not authorized to create users.' });
    }

    const tenant = await Tenant.findById(tenantId);
    if (!tenant) {
      return res.status(404).json({ success: false, message: 'Business not found.' });
    }
    const currentEmployees = await User.countDocuments({ tenantId, role: 'employee', isActive: true });
    if (currentEmployees >= tenant.maxEmployees) {
      return res.status(400).json({ success: false, message: 'Employee limit reached.' });
    }

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

router.delete('/:id', authenticate, async (req, res) => {
  try {
    const user = await User.findById(req.params.id);
    if (!user) {
      return res.status(404).json({ success: false, message: 'User not found.' });
    }

    if (user.role !== 'employee') {
      return res.status(403).json({ success: false, message: 'Only employee accounts can be deleted.' });
    }
    if (req.user.role === 'admin') {

      if (user.tenantId.toString() !== req.user.tenantId.toString()) {
        return res.status(403).json({ success: false, message: 'Access denied.' });
      }
      user.isActive = false;
      user.deletedAt = new Date();
      user.deletedBy = req.userId;
      user.deletionReason = req.body.reason || 'Admin requested deletion';
      await user.save();
    } else if (req.user.role === 'developer') {

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

router.put('/:id', authenticate, requireRole('developer'), async (req, res) => {
  try {
    const user = await User.findById(req.params.id);
    if (!user || !['admin', 'employee'].includes(user.role)) {
      return res.status(404).json({ success: false, message: 'User not found.' });
    }
    const { name, email, password, department, position, permissions, tenantId } = req.body;
    if (email !== undefined) {
      const normalizedEmail = String(email).trim().toLowerCase();
      const existing = await User.findOne({ email: normalizedEmail, _id: { $ne: user._id } });
      if (existing) return res.status(400).json({ success: false, message: 'Email already registered.' });
      user.email = normalizedEmail;
    }
    if (name !== undefined) user.name = String(name).trim();
    if (department !== undefined) user.department = department;
    if (position !== undefined) user.position = position;
    if (permissions !== undefined && user.role === 'employee') user.permissions = permissions;
    if (tenantId !== undefined) {
      const tenant = await Tenant.findById(tenantId);
      if (!tenant) return res.status(404).json({ success: false, message: 'Business not found.' });
      user.tenantId = tenant._id;
    }
    if (password !== undefined && String(password).length > 0) {
      if (String(password).length < 6) return res.status(400).json({ success: false, message: 'Password must be at least 6 characters.' });
      const { encryptedPassword, iv } = encryptPassword(String(password));
      user.encryptedPassword = encryptedPassword;
      user.passwordIV = iv;
      user.passwordHash = await bcrypt.hash(String(password), 12);
    }
    await user.save();
    res.json({ success: true, message: 'User updated.', user });
  } catch (error) {
    console.error('Update user error:', error);
    res.status(500).json({ success: false, message: 'Server error.' });
  }
});

router.put('/:id/suspend', authenticate, async (req, res) => {
  try {
    const user = await User.findById(req.params.id);
    if (!user || user.role !== 'employee' || !user.isActive) {
      return res.status(404).json({ success: false, message: 'Active employee not found.' });
    }
    if (req.user.role === 'admin' && String(user.tenantId) !== String(req.user.tenantId)) {
      return res.status(403).json({ success: false, message: 'Access denied.' });
    }
    if (!['admin', 'developer'].includes(req.user.role)) {
      return res.status(403).json({ success: false, message: 'Only admins and developers can suspend employees.' });
    }
    user.accountStatus = 'suspended';
    user.suspendedAt = new Date();
    user.suspendedBy = req.userId;
    user.suspensionReason = req.body.reason || 'Account suspended';
    await user.save();
    await createAuditLog({
      tenantId: user.tenantId,
      eventType: 'employee_suspended',
      severity: 'warning',
      userId: req.userId,
      userRole: req.user.role,
      action: `Suspended employee: ${user.name}`,
      details: { reason: user.suspensionReason },
      ipAddress: req.ip,
      userAgent: req.headers['user-agent']
    });
    res.json({ success: true, message: 'Employee suspended.' });
  } catch (error) {
    console.error('Suspend employee error:', error);
    res.status(500).json({ success: false, message: 'Server error.' });
  }
});

router.put('/:id/reactivate', authenticate, async (req, res) => {
  try {
    const user = await User.findById(req.params.id);
    if (!user || user.role !== 'employee' || !user.isActive) {
      return res.status(404).json({ success: false, message: 'Employee not found.' });
    }
    if (req.user.role === 'admin' && String(user.tenantId) !== String(req.user.tenantId)) {
      return res.status(403).json({ success: false, message: 'Access denied.' });
    }
    if (!['admin', 'developer'].includes(req.user.role)) {
      return res.status(403).json({ success: false, message: 'Only admins and developers can reactivate employees.' });
    }
    user.accountStatus = 'active';
    user.suspendedAt = null;
    user.suspendedBy = null;
    user.suspensionReason = null;
    await user.save();
    await createAuditLog({
      tenantId: user.tenantId,
      eventType: 'employee_reactivated',
      userId: req.userId,
      userRole: req.user.role,
      action: `Reactivated employee: ${user.name}`,
      ipAddress: req.ip,
      userAgent: req.headers['user-agent']
    });
    res.json({ success: true, message: 'Employee reactivated.' });
  } catch (error) {
    console.error('Reactivate employee error:', error);
    res.status(500).json({ success: false, message: 'Server error.' });
  }
});

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