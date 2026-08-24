const express = require('express');
const router = express.Router();
const Sale = require('../models/Sale');
const Damage = require('../models/Damage');
const Product = require('../models/Product');
const { authenticate, requireActiveTenant, requirePermission } = require('../middleware/auth');

// GET /api/reports/profit - Daily/Monthly/Yearly profit
router.get('/profit', authenticate, requireActiveTenant, requirePermission('view_profits'), async (req, res) => {
  try {
    const tenantId = req.user.role === 'developer' ? req.query.tenantId : req.user.tenantId;
    const { period = 'daily', startDate, endDate } = req.query;

    const today = new Date();
    let start, end;

    if (startDate && endDate) {
      start = new Date(startDate);
      end = new Date(endDate);
    } else if (period === 'daily') {
      start = new Date(today);
      start.setHours(0, 0, 0, 0);
      end = new Date(today);
      end.setHours(23, 59, 59, 999);
    } else if (period === 'monthly') {
      start = new Date(today.getFullYear(), today.getMonth(), 1);
      end = new Date(today.getFullYear(), today.getMonth() + 1, 0, 23, 59, 59, 999);
    } else if (period === 'yearly') {
      start = new Date(today.getFullYear(), 0, 1);
      end = new Date(today.getFullYear(), 11, 31, 23, 59, 59, 999);
    }

    const sales = await Sale.find({
      tenantId,
      saleDate: { $gte: start, $lte: end }
    });

    const damages = await Damage.find({
      tenantId,
      reportDate: { $gte: start, $lte: end }
    });

    const totalRevenue = sales.reduce((sum, s) => sum + s.totalAmount, 0);
    const totalCost = sales.reduce((sum, s) => sum + (s.costPrice * s.quantity), 0);
    const totalProfit = sales.reduce((sum, s) => sum + s.profit, 0);
    const totalDamageLoss = damages.reduce((sum, d) => sum + d.estimatedLoss, 0);
    const netProfit = totalProfit - totalDamageLoss;

    // Breakdown by product
    const productBreakdown = {};
    sales.forEach(sale => {
      const key = sale.productId.toString();
      if (!productBreakdown[key]) {
        productBreakdown[key] = { revenue: 0, cost: 0, profit: 0, quantity: 0 };
      }
      productBreakdown[key].revenue += sale.totalAmount;
      productBreakdown[key].cost += sale.costPrice * sale.quantity;
      productBreakdown[key].profit += sale.profit;
      productBreakdown[key].quantity += sale.quantity;
    });

    res.json({
      success: true,
      report: {
        period,
        startDate: start,
        endDate: end,
        totalRevenue,
        totalCost,
        totalProfit,
        totalDamageLoss,
        netProfit,
        totalSales: sales.length,
        totalDamageReports: damages.length,
        productBreakdown
      }
    });
  } catch (error) {
    res.status(500).json({ success: false, message: 'Server error.' });
  }
});

// GET /api/reports/inventory - Inventory summary
router.get('/inventory', authenticate, requireActiveTenant, async (req, res) => {
  try {
    const tenantId = req.user.role === 'developer' ? req.query.tenantId : req.user.tenantId;

    const products = await Product.find({ tenantId, isActive: true }).populate('categoryId', 'name');
    const totalProducts = products.length;
    const totalStockValue = products.reduce((sum, p) => {
      const pieceValue = p.costPrice * p.currentStock;
      const boxValue = (p.boxCostPrice || p.costPrice * (p.unitsPerBox || 1)) * (p.stockBoxes || 0);
      return sum + pieceValue + boxValue;
    }, 0);
    const totalRetailValue = products.reduce((sum, p) => {
      const pieceValue = p.sellingPrice * p.currentStock;
      const boxValue = (p.boxSellingPrice || p.sellingPrice * (p.unitsPerBox || 1)) * (p.stockBoxes || 0);
      return sum + pieceValue + boxValue;
    }, 0);
    const lowStockProducts = products.filter(p => p.currentStock <= p.minimumStock);
    const outOfStock = products.filter(p => p.currentStock === 0 && (!p.stockBoxes || p.stockBoxes === 0));

    res.json({
      success: true,
      inventory: {
        totalProducts,
        totalStockValue,
        totalRetailValue,
        lowStockCount: lowStockProducts.length,
        outOfStockCount: outOfStock.length,
        lowStockProducts: lowStockProducts.map(p => ({
          id: p._id,
          name: p.name,
          currentStock: p.currentStock,
          minimumStock: p.minimumStock,
          category: p.categoryId?.name
        })),
        outOfStockProducts: outOfStock.map(p => ({
          id: p._id,
          name: p.name,
          category: p.categoryId?.name
        }))
      }
    });
  } catch (error) {
    res.status(500).json({ success: false, message: 'Server error.' });
  }
});

module.exports = router;
