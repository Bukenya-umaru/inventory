const express = require('express');
const router = express.Router();
const Expense = require('../models/Expense');
const Category = require('../models/Category');
const { createAuditLog } = require('../utils/audit');
const {
  authenticate,
  requireActiveTenant,
  requirePermission
} = require('../middleware/auth');

router.get('/', authenticate, requireActiveTenant, async (req, res) => {
  try {
    const tenantId =
      req.user.role === 'developer' ? req.query.tenantId : req.user.tenantId;
    const { startDate, endDate } = req.query;
    const query = { tenantId };
    if (startDate || endDate) {
      query.expenseDate = {};
      if (startDate) query.expenseDate.$gte = new Date(startDate);
      if (endDate) query.expenseDate.$lte = new Date(endDate);
    }

    const expenses = await Expense.find(query)
      .populate('categoryId', 'name type')
      .populate('recordedBy', 'name')
      .sort({ expenseDate: -1 })
      .limit(200);

    res.json({ success: true, expenses });
  } catch (error) {
    console.error('List expenses error:', error);
    res.status(500).json({ success: false, message: 'Server error.' });
  }
});

router.post(
  '/',
  authenticate,
  requireActiveTenant,
  requirePermission('record_expenses'),
  async (req, res) => {
    try {
      const {
        categoryId,
        amount,
        description,
        paymentMethod,
        expenseDate
      } = req.body;
      const numericAmount = Number(amount);

      if (!categoryId || !Number.isFinite(numericAmount) || numericAmount <= 0) {
        return res.status(400).json({
          success: false,
          message: 'Expense category and an amount greater than 0 are required.'
        });
      }

      const tenantId =
        req.user.role === 'developer' ? req.body.tenantId : req.user.tenantId;
      const category = await Category.findOne({
        _id: categoryId,
        tenantId,
        isActive: true,
        type: 'expense'
      });
      if (!category) {
        return res.status(400).json({
          success: false,
          message: 'Invalid expense category.'
        });
      }

      const expense = await Expense.create({
        tenantId,
        categoryId,
        amount: numericAmount,
        description,
        paymentMethod,
        expenseDate: expenseDate ? new Date(expenseDate) : undefined,
        recordedBy: req.userId
      });

      await createAuditLog({
        tenantId,
        eventType: 'purchase_recorded',
        userId: req.userId,
        userRole: req.user.role,
        action: `Recorded expense: ${category.name} — ${numericAmount}`,
        details: {
          expenseId: expense._id,
          category: category.name,
          amount: numericAmount
        },
        ipAddress: req.ip
      });

      res.status(201).json({
        success: true,
        message: 'Expense recorded.',
        expense
      });
    } catch (error) {
      console.error('Record expense error:', error);
      res.status(500).json({ success: false, message: 'Server error.' });
    }
  }
);

module.exports = router;
