const express = require('express');
const router = express.Router();
const User = require('../models/User');
const PasswordViewLog = require('../models/PasswordViewLog');
const { decryptPassword } = require('../utils/encryption');
const { createAuditLog } = require('../utils/audit');
const { authenticate } = require('../middleware/auth');

const canViewPassword = (viewer, targetUser) => {

  if (viewer.role === 'developer') {
    return true;
  }

  if (viewer.role === 'admin') {
    if (viewer.tenantId.toString() !== targetUser.tenantId.toString()) {
      return false;
    }
    if (targetUser.role !== 'employee') {
      return false;
    }
    return true;
  }

  return false;
};

router.get('/view/:userId', authenticate, async (req, res) => {
  try {
    const targetUser = await User.findById(req.params.userId);
    if (!targetUser) {
      return res.status(404).json({ success: false, message: 'User not found.' });
    }

    if (!canViewPassword(req.user, targetUser)) {
      return res.status(403).json({ success: false, message: 'Not authorized to view this password.' });
    }

    const decryptedPassword = decryptPassword(targetUser.encryptedPassword, targetUser.passwordIV);

    const log = new PasswordViewLog({
      tenantId: targetUser.tenantId,
      viewerId: req.userId,
      viewerRole: req.user.role,
      targetUserId: targetUser._id,
      targetRole: targetUser.role,
      ipAddress: req.ip,
      userAgent: req.headers['user-agent']
    });
    await log.save();

    targetUser.passwordViewCount += 1;
    targetUser.lastPasswordView = new Date();
    await targetUser.save();

    await createAuditLog({
      tenantId: targetUser.tenantId,
      eventType: 'password_viewed',
      severity: 'warning',
      userId: req.userId,
      userRole: req.user.role,
      action: `Viewed password of: ${targetUser.name}`,
      details: { targetUser: targetUser.name, targetRole: targetUser.role },
      ipAddress: req.ip,
      userAgent: req.headers['user-agent']
    });

    res.json({
      success: true,
      password: decryptedPassword,
      visibleFor: req.user.role === 'developer' ? 60 : 30,
      message: 'Password view logged for security.'
    });
  } catch (error) {
    console.error('View password error:', error);
    res.status(500).json({ success: false, message: 'Server error.' });
  }
});

router.get('/audit', authenticate, async (req, res) => {
  try {
    let query = {};
    if (req.user.role === 'admin') {
      query.tenantId = req.user.tenantId;
    } else if (req.user.role !== 'developer') {
      return res.status(403).json({ success: false, message: 'Access denied.' });
    }

    const logs = await PasswordViewLog.find(query)
      .populate('viewerId', 'name email role')
      .populate('targetUserId', 'name email role')
      .populate('tenantId', 'businessName')
      .sort({ timestamp: -1 })
      .limit(100);

    res.json({ success: true, logs });
  } catch (error) {
    res.status(500).json({ success: false, message: 'Server error.' });
  }
});

router.put('/reset/:userId', authenticate, async (req, res) => {
  try {
    const { newPassword } = req.body;
    if (!newPassword || newPassword.length < 6) {
      return res.status(400).json({ success: false, message: 'New password must be at least 6 characters.' });
    }

    const targetUser = await User.findById(req.params.userId);
    if (!targetUser) {
      return res.status(404).json({ success: false, message: 'User not found.' });
    }

    if (!canViewPassword(req.user, targetUser)) {
      return res.status(403).json({ success: false, message: 'Not authorized to reset this password.' });
    }

    const bcrypt = require('bcryptjs');
    const { encryptPassword } = require('../utils/encryption');

    const { encryptedPassword, iv } = encryptPassword(newPassword);
    targetUser.encryptedPassword = encryptedPassword;
    targetUser.passwordIV = iv;
    targetUser.passwordHash = await bcrypt.hash(newPassword, 12);
    await targetUser.save();

    res.json({ success: true, message: 'Password reset successfully.' });
  } catch (error) {
    res.status(500).json({ success: false, message: 'Server error.' });
  }
});

module.exports = router;