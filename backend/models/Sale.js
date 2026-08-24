const mongoose = require('mongoose');

const saleSchema = new mongoose.Schema({
  tenantId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Tenant',
    required: true
  },
  productId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Product',
    required: true
  },
  quantity: {
    type: Number,
    required: true,
    min: 1
  },
  unitPrice: {
    type: Number,
    required: true,
    min: 0
  },
  costPrice: {
    type: Number,
    required: true,
    min: 0
  },
  totalAmount: {
    type: Number,
    required: true
  },
  profit: {
    type: Number,
    required: true
  },
  saleUnit: {
    type: String,
    enum: ['piece', 'box'],
    default: 'piece'
  },
  paymentMethod: {
    type: String,
    enum: ['cash', 'card', 'transfer', 'credit'],
    default: 'cash'
  },
  customerName: {
    type: String
  },
  notes: {
    type: String
  },
  recordedBy: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  saleDate: {
    type: Date,
    default: Date.now
  },
  createdAt: {
    type: Date,
    default: Date.now
  }
});

saleSchema.index({ tenantId: 1, saleDate: -1 });
saleSchema.index({ tenantId: 1, productId: 1 });

module.exports = mongoose.model('Sale', saleSchema);
