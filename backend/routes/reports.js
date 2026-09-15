const express = require('express');
const router = express.Router();
const Sale = require('../models/Sale');
const Damage = require('../models/Damage');
const Product = require('../models/Product');
const { authenticate, requireActiveTenant, requirePermission } = require('../middleware/auth');

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

router.get('/detailed', authenticate, requireActiveTenant, async (req, res) => {
  try {
    const tenantId = req.user.role === 'developer' ? req.query.tenantId : req.user.tenantId;
    const { period = 'daily', startDate, endDate } = req.query;

    const today = new Date();
    let start, end;

    if (startDate && endDate) {
      start = new Date(startDate);
      end = new Date(endDate);
      end.setHours(23, 59, 59, 999);
    } else if (period === 'daily') {
      start = new Date(today);
      start.setHours(0, 0, 0, 0);
      end = new Date(today);
      end.setHours(23, 59, 59, 999);
    } else if (period === 'weekly') {
      start = new Date(today);
      start.setDate(today.getDate() - today.getDay());
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

    const sales = await Sale.find({ tenantId, saleDate: { $gte: start, $lte: end } })
      .populate('productId', 'name')
      .populate('recordedBy', 'name')
      .sort({ saleDate: -1 });

    const damages = await Damage.find({ tenantId, reportDate: { $gte: start, $lte: end } })
      .populate('productId', 'name')
      .populate('reportedBy', 'name')
      .sort({ reportDate: -1 });

    const products = await Product.find({ tenantId, isActive: true }).populate('categoryId', 'name');

    const allProductsMap = {};
    products.forEach(p => {
      const name = p.name;
      allProductsMap[name] = {
        id: p._id,
        name: p.name,
        category: p.categoryId?.name || '',
        costPrice: p.costPrice,
        sellingPrice: p.sellingPrice,
        currentStock: p.currentStock,
        stockBoxes: p.stockBoxes,
        unitsPerBox: p.unitsPerBox,
        sellingUnit: p.sellingUnit,
        minimumStock: p.minimumStock,
        totalStockPieces: (p.stockBoxes || 0) * (p.unitsPerBox || 1) + (p.currentStock || 0),

        revenue: 0,
        profit: 0,
        quantitySold: 0,
        costOfGoodsSold: 0,
        salesCount: 0,

        loss: 0,
        quantityDamaged: 0,
        damageCount: 0,
      };
    });

    const productMap = {};
    sales.forEach(s => {
      const name = s.productId?.name || 'Unknown';
      if (!productMap[name]) productMap[name] = { revenue: 0, profit: 0, quantity: 0, cost: 0, salesCount: 0 };
      productMap[name].revenue += s.totalAmount;
      productMap[name].profit += s.profit;
      productMap[name].quantity += s.quantity;
      productMap[name].cost += s.costPrice * s.quantity;
      productMap[name].salesCount += 1;

      if (allProductsMap[name]) {
        allProductsMap[name].revenue += s.totalAmount;
        allProductsMap[name].profit += s.profit;
        allProductsMap[name].quantitySold += s.quantity;
        allProductsMap[name].costOfGoodsSold += s.costPrice * s.quantity;
        allProductsMap[name].salesCount += 1;
      } else {

        allProductsMap[name] = {
          id: null,
          name,
          category: '',
          costPrice: 0,
          sellingPrice: 0,
          currentStock: 0,
          stockBoxes: 0,
          unitsPerBox: 1,
          sellingUnit: 'piece',
          minimumStock: 0,
          totalStockPieces: 0,
          revenue: s.totalAmount,
          profit: s.profit,
          quantitySold: s.quantity,
          costOfGoodsSold: s.costPrice * s.quantity,
          salesCount: 1,
          loss: 0,
          quantityDamaged: 0,
          damageCount: 0,
        };
      }
    });

    const damageMap = {};
    damages.forEach(d => {
      const name = d.productId?.name || 'Unknown';
      if (!damageMap[name]) damageMap[name] = { loss: 0, quantity: 0, damageCount: 0 };
      damageMap[name].loss += d.estimatedLoss;
      damageMap[name].quantity += d.quantity;
      damageMap[name].damageCount += 1;

      if (allProductsMap[name]) {
        allProductsMap[name].loss += d.estimatedLoss;
        allProductsMap[name].quantityDamaged += d.quantity;
        allProductsMap[name].damageCount += 1;
      } else {
        if (!allProductsMap[name]) {
          allProductsMap[name] = {
            id: null, name, category: '', costPrice: 0, sellingPrice: 0,
            currentStock: 0, stockBoxes: 0, unitsPerBox: 1, sellingUnit: 'piece',
            minimumStock: 0, totalStockPieces: 0,
            revenue: 0, profit: 0, quantitySold: 0, costOfGoodsSold: 0, salesCount: 0,
            loss: d.estimatedLoss, quantityDamaged: d.quantity, damageCount: 1,
          };
        }
      }
    });

    const totalRevenue = sales.reduce((sum, s) => sum + s.totalAmount, 0);
    const totalProfit = sales.reduce((sum, s) => sum + s.profit, 0);
    const totalDamageLoss = damages.reduce((sum, d) => sum + d.estimatedLoss, 0);

    res.json({
      success: true,
      report: {
        period,
        startDate: start,
        endDate: end,
        totalRevenue,
        totalProfit,
        totalDamageLoss,
        netProfit: totalProfit - totalDamageLoss,
        totalSales: sales.length,
        totalDamageReports: damages.length,
        allProducts: allProductsMap,
        productBreakdown: productMap,
        damageBreakdown: damageMap,
        sales: sales.map(s => ({
          id: s._id,
          productName: s.productId?.name || 'Unknown',
          quantity: s.quantity,
          saleUnit: s.saleUnit,
          unitPrice: s.unitPrice,
          totalAmount: s.totalAmount,
          profit: s.profit,
          customerName: s.customerName,
          recordedBy: s.recordedBy?.name,
          saleDate: s.saleDate
        })),
        damages: damages.map(d => ({
          id: d._id,
          productName: d.productId?.name || 'Unknown',
          quantity: d.quantity,
          damageUnit: d.damageUnit,
          reason: d.reason,
          estimatedLoss: d.estimatedLoss,
          reportedBy: d.reportedBy?.name,
          reportDate: d.reportDate
        }))
      }
    });
  } catch (error) {
    console.error('Detailed report error:', error);
    res.status(500).json({ success: false, message: 'Server error.' });
  }
});

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