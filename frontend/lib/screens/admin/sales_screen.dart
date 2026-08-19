import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Sales', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text('Revenue: \$${totalRev.toStringAsFixed(2)} • Profit: \$${totalProfit.toStringAsFixed(2)}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _showRecordSale(),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Record Sale'),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _sales.length,
                  itemBuilder: (ctx, i) {
                    final s = _sales[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 6),
                      child: ListTile(
                        title: Text(s.productName ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text('Qty: ${s.quantity} • \$${s.unitPrice.toStringAsFixed(2)} each'),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('\$${s.totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text('+\$${s.profit.toStringAsFixed(2)} profit',
                              style: const TextStyle(fontSize: 11, color: AppTheme.success)),
                            Text(DateFormat('MMM d').format(s.saleDate), style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
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
                  items: _products.map((p) => DropdownMenuItem(value: p,
                    child: Text('${p.name} (Stock: ${p.currentStock})'))).toList(),
                  onChanged: (v) {
                    setDialogState(() {
                      selectedProduct = v;
                      priceCtrl.text = v?.sellingPrice.toString() ?? '';
                    });
                  },
                ),
                const SizedBox(height: 12),
                TextField(controller: qtyCtrl, decoration: const InputDecoration(labelText: 'Quantity'),
                  keyboardType: TextInputType.number),
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
