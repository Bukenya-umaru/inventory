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
                    Text('Total loss: \$${totalLoss.toStringAsFixed(2)}', style: TextStyle(fontSize: AppTheme.fontSize(context, 13), color: AppTheme.secondaryText(context))),
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
                        leading: const Icon(Icons.warning_amber, color: AppTheme.warning),
                        title: Text(d.productName ?? 'Unknown', maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: AppTheme.fontSize(context, 14))),
                        subtitle: Text('${d.damageUnit == 'box' ? 'Box' : 'Piece'}: ${d.reason}', maxLines: 1, overflow: TextOverflow.ellipsis,
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
    String damageUnit = 'piece';
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
                      if (v != null) damageUnit = 'piece';
                    });
                  },
                ),
                if (selectedProduct == null || selectedProduct!.sellsAsBox) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Damage Unit'),
                    value: (selectedProduct != null && !selectedProduct!.sellsAsBox) ? 'piece' : damageUnit,
                    items: const [
                      DropdownMenuItem(value: 'piece', child: Text('Individual Pieces')),
                      DropdownMenuItem(value: 'box', child: Text('Full Box')),
                    ],
                    onChanged: (v) => setDialogState(() => damageUnit = v ?? 'piece'),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(controller: qtyCtrl, decoration: const InputDecoration(labelText: 'Quantity'),
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setDialogState(() {})),
                // Box opening warning
                if (damageUnit == 'piece' && selectedProduct != null &&
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
                            'No loose pieces. A box will be opened (${selectedProduct!.unitsPerBox} pc/box).',
                            style: TextStyle(fontSize: AppTheme.fontSize(context, 12), color: AppTheme.warning),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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
                  'damageUnit': damageUnit,
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
