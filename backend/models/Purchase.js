const mongoose = require('mongoose');

const purchaseSchema = new mongoose.Schema({
  tenantId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Tenant',
    required: true
  },
  // Pending = awaiting business-owner approval (stock not yet applied to the
  // product). Approved = owner accepted the record and stock has been added.
  status: {
    type: String,
    enum: ['pending', 'approved'],
    default: 'pending'
  },
  approvedBy: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    default: null
  },
  approvedAt: {
    type: Date,
    default: null
  },
  // Edit trail while the record is still pending (before owner approval).
  editHistory: [{
    editedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    editedAt: { type: Date, default: Date.now },
    changes: { type: mongoose.Schema.Types.Mixed }
  }],
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
  // Free-text snapshot kept for old records; new records link to a
  // Supplier document via supplierId.
  supplier: {
    type: String
  },
  supplierId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Supplier',
    default: null
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
  creditPaid: {
    type: Boolean,
    default: false
  },
  creditPaidAt: {
    type: Date,
    default: null
  },
  creditPaidBy: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    default: null
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
purchaseSchema.index({ tenantId: 1, status: 1 });

module.exports = mongoose.model('Purchase', purchaseSchema);