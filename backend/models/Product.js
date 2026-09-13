const mongoose = require('mongoose');

const productSchema = new mongoose.Schema({
  name: {
    type: String,
    required: true,
    trim: true
  },
  description: {
    type: String
  },
  sku: {
    type: String,
    trim: true
  },
  categoryId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Category',
    required: true
  },
  tenantId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Tenant',
    required: true
  },
  costPrice: {
    type: Number,
    required: true,
    min: 0
  },
  sellingPrice: {
    type: Number,
    required: true,
    min: 0
  },
  currentStock: {
    type: Number,
    required: true,
    default: 0,
    min: 0
  },
  minimumStock: {
    type: Number,
    default: 5,
    min: 0
  },
  unit: {
    type: String,
    default: 'piece'
  },
  sellingUnit: {
    type: String,
    enum: ['piece', 'box'],
    default: 'piece'
  },
  unitsPerBox: {
    type: Number,
    default: 1,
    min: 1
  },
  stockBoxes: {
    type: Number,
    default: 0,
    min: 0
  },
  boxSellingPrice: {
    type: Number,
    min: 0
  },
  boxCostPrice: {
    type: Number,
    min: 0
  },
  isActive: {
    type: Boolean,
    default: true
  },
  // Price history: every distinct buy/sell price the product has had.
  // Each purchase keeps its own unitCost/unitSellingPrice, so old batches
  // retain their original buy price even after prices change.
  priceHistory: [{
    costPrice: { type: Number, required: true },   // per piece
    sellingPrice: { type: Number, required: true }, // per piece
    boxCostPrice: { type: Number },
    boxSellingPrice: { type: Number },
    unitsPerBox: { type: Number },
    source: { type: String, enum: ['created', 'restock', 'edit'], default: 'restock' },
    changedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    changedAt: { type: Date, default: Date.now }
  }],
  createdBy: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User'
  },
  createdAt: {
    type: Date,
    default: Date.now
  },
  updatedAt: {
    type: Date,
    default: Date.now
  }
});

productSchema.pre('save', function(next) {
  this.updatedAt = new Date();
  next();
});

productSchema.index({ tenantId: 1, name: 1 });
productSchema.index({ tenantId: 1, categoryId: 1 });
productSchema.index({ tenantId: 1, sku: 1 });

module.exports = mongoose.model('Product', productSchema);
