const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const path = require('path');
require('dotenv').config();

const app = express();

app.use(helmet());
app.use(cors({
  origin: process.env.NODE_ENV === 'production'
    ? process.env.ALLOWED_ORIGINS?.split(',') || []
    : (origin, callback) => {

        if (!origin || /^https?:\/\/localhost(:\d+)?(\/.*)?$/.test(origin) || /^https?:\/\/127\.0\.0\.1(:\d+)?(\/.*)?$/.test(origin)) {
          callback(null, true);
        } else {
          callback(new Error('Not allowed by CORS'));
        }
      },
  credentials: true
}));

const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, 
  max: 100,
  message: 'Too many requests, please try again later.'
});
app.use('/api/', limiter);

app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

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