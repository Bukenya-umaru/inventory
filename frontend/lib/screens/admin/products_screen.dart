import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../models/product.dart';
import '../../utils/theme.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});
  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  List<Product> _products = [];
  bool _loading = true;
  String _search = '';
  bool _lowStockOnly = false;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.getProducts(search: _search.isNotEmpty ? _search : null, lowStock: _lowStockOnly);
      final list = (res['products'] as List).map((p) => Product.fromJson(p)).toList();
      setState(() { _products = list; _loading = false; });
    } catch (e) { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmall = size.height < 600 || size.width < 400;

    return Column(
      children: [
        // Search + filter bar
        Padding(
          padding: EdgeInsets.all(isSmall ? 10 : 16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search products...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: isSmall ? 10 : 14),
                      ),
                      style: TextStyle(fontSize: isSmall ? 13 : 15),
                      onChanged: (v) { _search = v; _load(); },
                    ),
                  ),
                  SizedBox(width: 8),
                  FilterChip(
                    label: Text('Low Stock', style: TextStyle(fontSize: isSmall ? 11 : 13)),
                    selected: _lowStockOnly,
                    onSelected: (v) { _lowStockOnly = v; _load(); },
                    selectedColor: AppTheme.warning.withValues(alpha: 0.1),
                    padding: EdgeInsets.symmetric(horizontal: isSmall ? 6 : 10),
                  ),
                  SizedBox(width: 4),
                  IconButton.filled(
                    onPressed: () => _showForm(),
                    icon: const Icon(Icons.add, size: 20),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Product list
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _products.isEmpty
                  ? const Center(child: Text('No products found'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: EdgeInsets.symmetric(horizontal: isSmall ? 10 : 16),
                        itemCount: _products.length,
                        itemBuilder: (ctx, i) {
                          final p = _products[i];
                          return Card(
                            margin: EdgeInsets.only(bottom: isSmall ? 6 : 8),
                            child: Padding(
                              padding: EdgeInsets.all(isSmall ? 10 : 14),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(p.name,
                                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: isSmall ? 13 : 15)),
                                        SizedBox(height: 2),
                                        Text('${p.categoryName ?? "No category"}',
                                          style: TextStyle(fontSize: isSmall ? 11 : 12, color: Colors.grey.shade500)),
                                        SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Text('Cost: \$${p.costPrice.toStringAsFixed(2)}',
                                              style: TextStyle(fontSize: isSmall ? 11 : 12, color: Colors.grey.shade600)),
                                            const SizedBox(width: 8),
                                            Text('Price: \$${p.sellingPrice.toStringAsFixed(2)}',
                                              style: TextStyle(fontSize: isSmall ? 11 : 12, fontWeight: FontWeight.w600)),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    children: [
                                      Container(
                                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: p.isLowStock ? AppTheme.danger.withValues(alpha: 0.1) : Colors.green.shade50,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text('${p.currentStock}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600, fontSize: isSmall ? 13 : 14,
                                            color: p.isLowStock ? AppTheme.danger : Colors.black87,
                                          )),
                                      ),
                                      SizedBox(height: 6),
                                      PopupMenuButton(
                                        padding: EdgeInsets.zero,
                                        itemBuilder: (_) => [
                                          const PopupMenuItem(value: 'edit', child: Text('Edit')),
                                          const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: AppTheme.danger))),
                                        ],
                                        onSelected: (v) {
                                          if (v == 'edit') _showForm(product: p);
                                          if (v == 'delete') _delete(p);
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  void _showForm({Product? product}) {
    final nameCtrl = TextEditingController(text: product?.name ?? '');
    final costCtrl = TextEditingController(text: product?.costPrice.toString() ?? '');
    final priceCtrl = TextEditingController(text: product?.sellingPrice.toString() ?? '');
    final stockCtrl = TextEditingController(text: product?.currentStock.toString() ?? '0');
    final minCtrl = TextEditingController(text: product?.minimumStock.toString() ?? '5');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(product != null ? 'Edit Product' : 'Add Product'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
              const SizedBox(height: 12),
              TextField(controller: costCtrl, decoration: const InputDecoration(labelText: 'Cost Price'), keyboardType: TextInputType.number),
              const SizedBox(height: 12),
              TextField(controller: priceCtrl, decoration: const InputDecoration(labelText: 'Selling Price'), keyboardType: TextInputType.number),
              const SizedBox(height: 12),
              TextField(controller: stockCtrl, decoration: const InputDecoration(labelText: 'Stock'), keyboardType: TextInputType.number),
              const SizedBox(height: 12),
              TextField(controller: minCtrl, decoration: const InputDecoration(labelText: 'Min Stock'), keyboardType: TextInputType.number),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final data = {
                'name': nameCtrl.text,
                'categoryId': product?.categoryId ?? '',
                'costPrice': double.tryParse(costCtrl.text) ?? 0,
                'sellingPrice': double.tryParse(priceCtrl.text) ?? 0,
                'currentStock': int.tryParse(stockCtrl.text) ?? 0,
                'minimumStock': int.tryParse(minCtrl.text) ?? 5,
              };
              if (product != null) {
                await ApiService.updateProduct(product.id, data);
              } else {
                await ApiService.createProduct(data);
              }
              if (ctx.mounted) Navigator.pop(ctx);
              _load();
            },
            child: Text(product != null ? 'Update' : 'Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _delete(Product p) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text('Delete "${p.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm == true) { await ApiService.deleteProduct(p.id); _load(); }
  }
}
