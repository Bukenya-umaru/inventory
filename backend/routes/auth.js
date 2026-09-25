const express = require('express');
const router = express.Router();
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const User = require('../models/User');
const Tenant = require('../models/Tenant');
const { encryptPassword, decryptPassword } = require('../utils/encryption');
const { createAuditLog } = require('../utils/audit');
const { authenticate } = require('../middleware/auth');

const generateToken = (userId, role) => {
  return jwt.sign({ userId, role }, process.env.JWT_SECRET, { expiresIn: '24h' });
};

router.post('/login', async (req, res) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({ success: false, message: 'Email and password required.' });
    }

    const user = await User.findOne({ email: email.toLowerCase() }).populate('tenantId');
    if (!user) {
      return res.status(401).json({ success: false, message: 'Invalid credentials.' });
    }

    if (!user.isActive) {
      return res.status(401).json({ success: false, message: 'Account is deactivated.' });
    }
    if (user.accountStatus === 'suspended') {
      return res.status(403).json({ success: false, message: 'Employee account is suspended.' });
    }

    if (user.role !== 'developer' && user.tenantId) {
      if (user.tenantId.status === 'suspended') {
        return res.status(403).json({ success: false, message: 'Business account is suspended.' });
      }
      if (user.tenantId.status === 'deleted') {
        return res.status(403).json({ success: false, message: 'Business account has been deleted.' });
      }
    }

    const isMatch = await bcrypt.compare(password, user.passwordHash);
    if (!isMatch) {
      await createAuditLog({
        eventType: 'login_failed',
        severity: 'warning',
        action: `Failed login attempt for ${email}`,
        ipAddress: req.ip,
        userAgent: req.headers['user-agent']
      });
      return res.status(401).json({ success: false, message: 'Invalid credentials.' });
    }

    user.lastLogin = new Date();
    await user.save();

    const token = generateToken(user._id, user.role);

    let branding = null;
    if (user.tenantId) {
      branding = {
        businessName: user.tenantId.businessName,
        businessLogo: user.tenantId.businessLogo,
        phoneNumber: user.tenantId.phoneNumber
      };
    }

    await createAuditLog({
      tenantId: user.tenantId?._id || null,
      eventType: 'login_success',
      userId: user._id,
      userRole: user.role,
      action: `Login successful: ${email}`,
      ipAddress: req.ip,
      userAgent: req.headers['user-agent']
    });

    res.json({
      success: true,
      token,
      user: {
        id: user._id,
        name: user.name,
        email: user.email,
        role: user.role,
        tenantId: user.tenantId?._id || null,
        permissions: user.permissions
      },
      branding
    });
  } catch (error) {
    console.error('Login error:', error);
    res.status(500).json({ success: false, message: 'Server error.' });
  }
});

router.post('/register-developer', async (req, res) => {
  try {

    const existingDev = await User.findOne({ role: 'developer' });
    if (existingDev) {
      return res.status(400).json({ success: false, message: 'Developer account already exists.' });
    }

    const { name, email, password } = req.body;
    if (!name || !email || !password) {
      return res.status(400).json({ success: false, message: 'All fields required.' });
    }

    const { encryptedPassword, iv } = encryptPassword(password);
    const passwordHash = await bcrypt.hash(password, 12);

    const developer = new User({
      name,
      email: email.toLowerCase(),
      encryptedPassword,
      passwordIV: iv,
      passwordHash,
      role: 'developer'
    });

    await developer.save();
    const token = generateToken(developer._id, 'developer');

    res.status(201).json({
      success: true,
      message: 'Developer account created.',
      token,
      user: {
        id: developer._id,
        name: developer.name,
        email: developer.email,
        role: developer.role
      }
    });
  } catch (error) {
    console.error('Register developer error:', error);
    res.status(500).json({ success: false, message: 'Server error.' });
  }
});

router.post('/change-password', authenticate, async (req, res) => {
  try {
    const { currentPassword, newPassword } = req.body;

    if (!currentPassword || !newPassword) {
      return res.status(400).json({ success: false, message: 'Current and new password required.' });
    }

    if (newPassword.length < 6) {
      return res.status(400).json({ success: false, message: 'New password must be at least 6 characters.' });
    }

    const user = await User.findById(req.userId);
    const isMatch = await bcrypt.compare(currentPassword, user.passwordHash);
    if (!isMatch) {
      return res.status(401).json({ success: false, message: 'Current password is incorrect.' });
    }

    const { encryptedPassword, iv } = encryptPassword(newPassword);
    user.encryptedPassword = encryptedPassword;
    user.passwordIV = iv;
    user.passwordHash = await bcrypt.hash(newPassword, 12);
    await user.save();

    await createAuditLog({
      tenantId: user.tenantId,
      eventType: 'password_changed',
      userId: user._id,
      userRole: user.role,
      action: `Password changed for ${user.email}`,
      ipAddress: req.ip,
      userAgent: req.headers['user-agent']
    });

    res.json({ success: true, message: 'Password changed successfully.' });
  } catch (error) {
    console.error('Change password error:', error);
    res.status(500).json({ success: false, message: 'Server error.' });
  }
});

router.get('/me', authenticate, async (req, res) => {
  try {
    let branding = null;
    if (req.user.tenantId) {
      const tenant = await Tenant.findById(req.user.tenantId);
      if (tenant) {
        branding = {
          businessName: tenant.businessName,
          businessLogo: tenant.businessLogo,
          phoneNumber: tenant.phoneNumber,
          ownerName: tenant.ownerName
        };
      }
    }

    res.json({
      success: true,
      user: {
        id: req.user._id,
        name: req.user.name,
        email: req.user.email,
        role: req.user.role,
        tenantId: req.user.tenantId,
        permissions: req.user.permissions
      },
      branding
    });
  } catch (error) {
    res.status(500).json({ success: false, message: 'Server error.' });
  }
});

module.exports = router;