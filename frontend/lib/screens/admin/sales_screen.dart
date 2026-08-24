import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../models/sale.dart';
import '../../models/product.dart';
import '../../utils/theme.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});
  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  List<Sale> _sales = [];
  List<Product> _products = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final salesRes = await ApiService.getSales();
      final prodRes = await ApiService.getProducts();
      setState(() {
        _sales = (salesRes['sales'] as List).map((s) => Sale.fromJson(s)).toList();
        _products = (prodRes['products'] as List).map((p) => Product.fromJson(p)).toList();
        _loading = false;
      });
    } catch (e) { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    final totalRev = _sales.fold(0.0, (s, sale) => s + sale.totalAmount);
    final totalProfit = _sales.fold(0.0, (s, sale) => s + sale.profit);

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(AppTheme.pad(context, 16)),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sales', style: TextStyle(fontSize: AppTheme.fontSize(context, 20), fontWeight: FontWeight.bold)),
                    Text('Revenue: \$${totalRev.toStringAsFixed(2)} • Profit: \$${totalProfit.toStringAsFixed(2)}',
                      style: TextStyle(fontSize: AppTheme.fontSize(context, 13), color: AppTheme.secondaryText(context))),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _showRecordSale(),
                icon: const Icon(Icons.add, size: 18),
                label: Text('Record Sale', style: TextStyle(fontSize: AppTheme.fontSize(context, 14))),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: AppTheme.pad(context, 16)),
                  itemCount: _sales.length,
                  itemBuilder: (ctx, i) {
                    final s = _sales[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 6),
                      child: ListTile(
                        title: Text(s.productName ?? 'Unknown', maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: AppTheme.fontSize(context, 14))),
                        subtitle: Text('Qty: ${s.quantity} ${s.saleUnit == 'box' ? 'box' : 'pc'} • \$${s.unitPrice.toStringAsFixed(2)} each',
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: AppTheme.fontSize(context, 12))),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('\$${s.totalAmount.toStringAsFixed(2)}', maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: AppTheme.fontSize(context, 13))),
                            Text('+\$${s.profit.toStringAsFixed(2)} profit', maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: AppTheme.fontSize(context, 11), color: AppTheme.success)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _showRecordSale() {
    Product? selectedProduct;
    String saleUnit = 'piece';
    final qtyCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final customerCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Record Sale'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<Product>(
                  decoration: const InputDecoration(labelText: 'Product'),
                  items: _products.map((p) {
                    String stockInfo = p.sellsAsBox
                        ? '${p.stockBoxes} bx, ${p.currentStock} pc'
                        : '${p.currentStock} pc';
                    return DropdownMenuItem(value: p,
                      child: Text('${p.name} ($stockInfo)'));
                  }).toList(),
                  onChanged: (v) {
                    setDialogState(() {
                      selectedProduct = v;
                      if (v != null) {
                        saleUnit = 'piece';
                        priceCtrl.text = v.sellingPrice.toString();
                      }
                    });
                  },
                ),
                if (selectedProduct == null || selectedProduct!.sellsAsBox) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Sell As'),
                    value: (selectedProduct != null && !selectedProduct!.sellsAsBox) ? 'piece' : saleUnit,
                    items: const [
                      DropdownMenuItem(value: 'piece', child: Text('Individual Pieces')),
                      DropdownMenuItem(value: 'box', child: Text('Full Box')),
                    ],
                    onChanged: (v) {
                      setDialogState(() {
                        saleUnit = v ?? 'piece';
                        if (selectedProduct != null) {
                          if (saleUnit == 'box') {
                            priceCtrl.text = selectedProduct!.boxSellingPrice?.toString() ?? (selectedProduct!.sellingPrice * selectedProduct!.unitsPerBox).toString();
                          } else {
                            priceCtrl.text = selectedProduct!.sellingPrice.toString();
                          }
                        }
                      });
                    },
                  ),
                ],
                const SizedBox(height: 12),
                TextField(controller: qtyCtrl, decoration: const InputDecoration(labelText: 'Quantity'),
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setDialogState(() {})),
                // Box opening warning
                if (saleUnit == 'piece' && selectedProduct != null &&
                    selectedProduct!.sellsAsBox &&
                    !selectedProduct!.hasLoosePieces &&
                    selectedProduct!.hasFullBoxes &&
                    (int.tryParse(qtyCtrl.text) ?? 0) > 0) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.warning.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber, size: 16, color: AppTheme.warning),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'No loose pieces available. A box will be opened (${selectedProduct!.unitsPerBox} pc/box).',
                            style: TextStyle(fontSize: AppTheme.fontSize(context, 12), color: AppTheme.warning),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(controller: priceCtrl, decoration: const InputDecoration(labelText: 'Unit Price'),
                  keyboardType: TextInputType.number),
                const SizedBox(height: 12),
                TextField(controller: customerCtrl, decoration: const InputDecoration(labelText: 'Customer Name')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success),
              onPressed: () async {
                if (selectedProduct == null || qtyCtrl.text.isEmpty) return;
                await ApiService.createSale({
                  'productId': selectedProduct!.id,
                  'quantity': int.tryParse(qtyCtrl.text) ?? 0,
                  'unitPrice': double.tryParse(priceCtrl.text) ?? selectedProduct!.sellingPrice,
                  'saleUnit': saleUnit,
                  'customerName': customerCtrl.text.isNotEmpty ? customerCtrl.text : null,
                });
                if (ctx.mounted) Navigator.pop(ctx);
                _load();
              },
              child: const Text('Record'),
            ),
          ],
        ),
      ),
    );
  }
}
