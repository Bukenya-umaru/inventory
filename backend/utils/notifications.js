const Product = require('../models/Product');
const { createAuditLog } = require('./audit');

/**
 * Creates a "low stock" notification (audit event) when a product's stock
 * has dropped to/below its minimum. The alert is tenant-scoped, so it shows
 * up in the activity feed of every user of the same business (admin and
 * employees). Fire-and-forget: failures are logged, never thrown, so the
 * calling route (sale/damage/purchase/edit) is never blocked.
 *
 * Dedupe: a Product.lowStockAlerted flag is set when the alert is created
 * and cleared on restock (see checkStockRecovery), so the same crossing does
 * not spam the feed repeatedly.
 *
 * @param {Object} product  Mongoose Product doc AFTER the stock change was saved
 * @param {Object} actor    { userId, userRole } of who triggered the change
 * @param {Object} [context] Optional context for the message
 * @param {string} [context.reason]  'sale' | 'damage' | 'restock-edit' | ...
 */
const notifyLowStock = async (product, actor = {}, context = {}) => {
  try {
    if (!product) return;

    const totalStock =
      (product.currentStock || 0) + (product.stockBoxes || 0) * (product.unitsPerBox || 1);
    const minimum = product.minimumStock ?? 0;

    // Below minimum, but not yet fully out — "low stock". Fully out of stock
    // is intentionally not alerted here (all stock gone); a threshold of 0
    // minimum means the owner disabled alerts for this product.
    if (minimum <= 0 || totalStock <= 0 || totalStock > minimum) {
      // Stock recovered — reset the flag so a future crossing alerts again
      if (product.lowStockAlerted && totalStock > minimum) {
        product.lowStockAlerted = false;
        await product.save().catch(() => {});
      }
      return;
    }

    if (product.lowStockAlerted) return; // already alerted for this crossing

    const unitLabel = product.sellingUnit === 'box' && (product.stockBoxes || 0) > 0
      ? 'box'
      : 'piece';

    const remaining = unitLabel === 'box'
      ? `${product.stockBoxes} box${product.stockBoxes === 1 ? '' : 'es'}`
      : `${totalStock} piece${totalStock === 1 ? '' : 's'}`;

    await createAuditLog({
      tenantId: product.tenantId,
      eventType: 'low_stock_alert',
      severity: 'warning',
      userId: actor.userId || null,
      userRole: actor.userRole || null,
      action: `Low stock: ${product.name} — ${remaining} left (minimum ${minimum})`,
      details: {
        productId: product._id,
        productName: product.name,
        currentStock: product.currentStock,
        stockBoxes: product.stockBoxes,
        unitsPerBox: product.unitsPerBox,
        totalStock,
        minimumStock: minimum,
        reason: context.reason || null
      }
    });

    product.lowStockAlerted = true;
    await product.save().catch(() => {});
  } catch (error) {
    console.error('Low stock notification error:', error);
  }
};

module.exports = { notifyLowStock };
