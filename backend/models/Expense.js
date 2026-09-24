const mongoose = require('mongoose');

const expenseSchema = new mongoose.Schema({
  tenantId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Tenant',
    required: true
  },
  categoryId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Category',
    required: true
  },
  amount: {
    type: Number,
    required: true,
    min: 0
  },
  description: {
    type: String,
    trim: true
  },
  paymentMethod: {
    type: String,
    enum: ['cash', 'credit', 'bank_transfer', 'mobile_money', 'other'],
    default: 'cash'
  },
  expenseDate: {
    type: Date,
    default: Date.now
  },
  recordedBy: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  createdAt: {
    type: Date,
    default: Date.now
  }
});

expenseSchema.index({ tenantId: 1, expenseDate: -1 });
expenseSchema.index({ tenantId: 1, categoryId: 1 });

module.exports = mongoose.model('Expense', expenseSchema);
