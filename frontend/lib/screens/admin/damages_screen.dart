import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../models/damage.dart';
import '../../models/product.dart';
import '../../utils/theme.dart';

class DamagesScreen extends StatefulWidget {
  const DamagesScreen({super.key});
  @override
  State<DamagesScreen> createState() => _DamagesScreenState();
}

class _DamagesScreenState extends State<DamagesScreen> {
  List<Damage> _damages = [];
  List<Product> _products = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final dmgRes = await ApiService.getDamages();
      final prodRes = await ApiService.getProducts();
      setState(() {
        _damages = (dmgRes['damages'] as List).map((d) => Damage.fromJson(d)).toList();
        _products = (prodRes['products'] as List).map((p) => Product.fromJson(p)).toList();
        _loading = false;
      });
    } catch (e) { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    final totalLoss = _damages.fold(0.0, (s, d) => s + d.estimatedLoss);
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
                    Text('Damage Reports', style: TextStyle(fontSize: AppTheme.fontSize(context, 20), fontWeight: FontWeight.bold)),
                    Text('Total loss: \$${totalLoss.toStringAsFixed(2)}', style: TextStyle(fontSize: AppTheme.fontSize(context, 13), color: Colors.grey.shade500)),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _showReport(),
                icon: const Icon(Icons.add, size: 18),
                label: Text('Report', style: TextStyle(fontSize: AppTheme.fontSize(context, 14))),
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: AppTheme.pad(context, 16)),
                  itemCount: _damages.length,
                  itemBuilder: (ctx, i) {
                    final d = _damages[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 6),
                      child: ListTile(
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        leading: const Icon(Icons.warning_amber, color: AppTheme.warning),
                        title: Text(d.productName ?? 'Unknown', maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: AppTheme.fontSize(context, 14))),
                        subtitle: Text(d.reason, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: AppTheme.fontSize(context, 12))),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Qty: ${d.quantity}', maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontWeight: FontWeight.w600, fontSize: AppTheme.fontSize(context, 13))),
                            Text('-\$${d.estimatedLoss.toStringAsFixed(2)}', maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: AppTheme.fontSize(context, 12), color: AppTheme.danger)),
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

  void _showReport() {
    Product? selectedProduct;
    final qtyCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Report Damage'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<Product>(
                  decoration: const InputDecoration(labelText: 'Product'),
                  items: _products.map((p) => DropdownMenuItem(value: p,
                    child: Text('${p.name} (Stock: ${p.currentStock})'))).toList(),
                  onChanged: (v) => setDialogState(() => selectedProduct = v),
                ),
                const SizedBox(height: 12),
                TextField(controller: qtyCtrl, decoration: const InputDecoration(labelText: 'Quantity'),
                  keyboardType: TextInputType.number),
                const SizedBox(height: 12),
                TextField(controller: reasonCtrl, decoration: const InputDecoration(labelText: 'Reason'),
                  maxLines: 3),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
              onPressed: () async {
                if (selectedProduct == null || qtyCtrl.text.isEmpty || reasonCtrl.text.isEmpty) return;
                await ApiService.createDamage({
                  'productId': selectedProduct!.id,
                  'quantity': int.tryParse(qtyCtrl.text) ?? 0,
                  'reason': reasonCtrl.text,
                });
                if (ctx.mounted) Navigator.pop(ctx);
                _load();
              },
              child: const Text('Report'),
            ),
          ],
        ),
      ),
    );
  }
}
