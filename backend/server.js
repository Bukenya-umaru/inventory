const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const path = require('path');
require('dotenv').config();

const app = express();

// Render / other PaaS hosts sit behind a reverse proxy — trust it so
// req.ip (used by rate limiting and audit logs) is the real client IP.
app.set('trust proxy', 1);

app.use(helmet({
  crossOriginResourcePolicy: { policy: 'cross-origin' } // allow frontend to load /uploads images
}));
// CORS whitelist comes from .env only — nothing hardcoded in code.
//   - ALLOWED_ORIGINS      : origins used when NODE_ENV=production
//   - ALLOWED_ORIGINS_DEV  : origins used in development
// Both are comma-separated lists of full origins (scheme + domain, no trailing slash).
// Requests with no Origin header (curl, Postman, Flutter mobile apps) are always allowed.
const isProduction = process.env.NODE_ENV === 'production';
const allowedOrigins = (isProduction
  ? process.env.ALLOWED_ORIGINS
  : (process.env.ALLOWED_ORIGINS_DEV || process.env.ALLOWED_ORIGINS)) || '';
const whitelist = allowedOrigins
  .split(',')
  .map((origin) => origin.trim())
  .filter(Boolean);

app.use(cors({
  credentials: false, // the API uses bearer tokens, no cookies
  origin(origin, callback) {
    if (!origin || whitelist.includes(origin)) {
      return callback(null, true);
    }
    const err = new Error(`Origin not allowed by CORS: ${origin}`);
    err.status = 403;
    return callback(err);
  }
}));

console.log(`🔒 CORS mode: ${isProduction ? 'production' : 'development'} — allowed origins: ${whitelist.length ? whitelist.join(', ') : '(none)'}`);
if (!isProduction && !whitelist.length) {
  console.warn('⚠️ No CORS origins set. Set ALLOWED_ORIGINS_DEV (dev) or ALLOWED_ORIGINS (prod) in .env.');
}

const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, 
  max: 100,
  message: 'Too many requests, please try again later.'
});
app.use('/api/', limiter);

app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

// App download: static APK hosting + release metadata API.
// Drop the built APK in backend/downloads (optionally with release.json).
app.use('/downloads', express.static(path.join(__dirname, 'downloads')));

mongoose.connect(process.env.MONGODB_URI)
  .then(() => console.log('✅ Connected to MongoDB'))
  .catch(err => console.error('❌ MongoDB connection error:', err));

app.use('/api/auth', require('./routes/auth'));
app.use('/api/tenants', require('./routes/tenants'));
app.use('/api/users', require('./routes/users'));
app.use('/api/products', require('./routes/products'));
app.use('/api/categories', require('./routes/categories'));
app.use('/api/sales', require('./routes/sales'));
app.use('/api/damages', require('./routes/damages'));
app.use('/api/purchases', require('./routes/purchases'));
app.use('/api/reports', require('./routes/reports'));
app.use('/api/audit', require('./routes/audit'));
app.use('/api/passwords', require('./routes/passwords'));
app.use('/api/app', require('./routes/app_download'));

app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(err.status || 500).json({
    success: false,
    message: err.message || 'Internal Server Error'
  });
});

const PORT = process.env.PORT || 5000;
app.listen(PORT, () => {
  console.log(`🚀 Server running on port ${PORT}`);
});

module.exports = app;