const jwt = require('jsonwebtoken');
const User = require('../models/User');

const authenticate = async (req, res, next) => {
  try {
    const token = req.header('Authorization')?.replace('Bearer ', '');
    if (!token) {
      return res.status(401).json({ success: false, message: 'Access denied. No token provided.' });
    }

    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    const user = await User.findById(decoded.userId).select('-passwordHash -encryptedPassword -passwordIV');

    if (!user || !user.isActive || user.accountStatus === 'suspended') {
      return res.status(401).json({ success: false, message: 'Invalid token or user inactive.' });
    }

    req.user = user;
    req.userId = decoded.userId;
    next();
  } catch (error) {
    if (error.name === 'TokenExpiredError') {
      return res.status(401).json({ success: false, message: 'Token expired.' });
    }
    res.status(401).json({ success: false, message: 'Invalid token.' });
  }
};

const requireRole = (...roles) => {
  return (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({ success: false, message: 'Not authenticated.' });
    }
    if (!roles.includes(req.user.role)) {
      return res.status(403).json({ success: false, message: 'Access denied. Insufficient permissions.' });
    }
    next();
  };
};

const requireActiveTenant = async (req, res, next) => {
  try {
    if (req.user.role === 'developer') {
      return next(); 
    }
    if (!req.user.tenantId) {
      return res.status(403).json({ success: false, message: 'No business associated.' });
    }
    const Tenant = require('../models/Tenant');
    const tenant = await Tenant.findById(req.user.tenantId);
    if (!tenant || tenant.status !== 'active') {
      return res.status(403).json({ success: false, message: 'Business account is not active.' });
    }
    req.tenant = tenant;
    next();
  } catch (error) {
    res.status(500).json({ success: false, message: 'Server error.' });
  }
};

const requirePermission = (permission) => {
  return (req, res, next) => {
    if (req.user.role === 'developer') {
      return next(); 
    }
    if (req.user.role === 'admin') {
      return next(); 
    }
    if (!req.user.permissions || !req.user.permissions.includes(permission)) {
      return res.status(403).json({ success: false, message: `Permission denied: ${permission}` });
    }
    next();
  };
};

module.exports = { authenticate, requireRole, requireActiveTenant, requirePermission };