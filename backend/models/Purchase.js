const mongoose = require('mongoose');

const purchaseSchema = new mongoose.Schema({
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
  purchaseUnit: {
    type: String,
    enum: ['piece', 'box'],
    default: 'box'
  },
  unitCost: {
    type: Number,
    required: true,
    min: 0
  },
  unitSellingPrice: {
    type: Number,
    min: 0
  },
  totalCost: {
    type: Number,
    required: true
  },
  supplier: {
    type: String
  },
  supplierPhone: {
    type: String
  },
  supplierEmail: {
    type: String
  },
  invoiceNumber: {
    type: String
  },
  paymentMethod: {
    type: String,
    enum: ['cash', 'credit', 'bank_transfer', 'mobile_money', 'other'],
    default: 'cash'
  },
  notes: {
    type: String
  },
  recordedBy: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  purchaseDate: {
    type: Date,
    default: Date.now
  },
  createdAt: {
    type: Date,
    default: Date.now
  }
});

purchaseSchema.index({ tenantId: 1, purchaseDate: -1 });

module.exports = mongoose.model('Purchase', purchaseSchema);