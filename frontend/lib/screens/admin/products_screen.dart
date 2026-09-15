import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../services/app_events.dart';
import '../../models/product.dart';
import '../../models/category.dart';
import '../../utils/theme.dart';
import '../../utils/currency.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});
  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  List<Product> _products = [];
  List<Category> _categories = [];
  bool _loading = true;
  String _search = '';
  bool _lowStockOnly = false;
  Timer? _searchTimer;

  @override
  void initState() {
    super.initState();
    _load();

    AppEvents.instance.subscribe(_onEvent);
  }

  void _onEvent(String event) {
    if (!mounted) return;
    if (event == 'products') {
      _load(silent: true);
    }
  }

  @override
  void dispose() {
    AppEvents.instance.unsubscribe(_onEvent);
    _searchTimer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ApiService.getProducts(
          search: _search.isNotEmpty ? _search : null,
          lowStock: _lowStockOnly,
        ),
        ApiService.getCategories(),
      ]);
      final res = results[0];
      final catRes = results[1];
      final list =
          (res['products'] as List).map((p) => Product.fromJson(p)).toList();
      final cats =
          (catRes['categories'] as List).map((c) => Category.fromJson(c)).toList();
      setState(() {
        _products = list;
        _categories = cats;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  int get _totalProducts => _products.length;
  int get _inStock =>
      _products.where((p) => p.totalStockPieces > 0).length;
  int get _lowStock =>
      _products.where((p) => p.totalStockPieces > 0 && p.totalStockPieces <= p.minimumStock).length;
  int get _outOfStock =>
      _products.where((p) => p.totalStockPieces == 0).length;
  double get _totalValue => _products.fold(
      0.0, (s, p) => s + (p.costPrice * p.totalStockPieces));

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmall = size.height < 600 || size.width < 400;
    final isWide = size.width >= 900;

    return Column(
      children: [

        Padding(
          padding: EdgeInsets.fromLTRB(
              isSmall ? 12 : AppTheme.pad(context, 16),
              isSmall ? 12 : AppTheme.pad(context, 16),
              isSmall ? 12 : AppTheme.pad(context, 16),
              isSmall ? 8 : AppTheme.pad(context, 8)),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Products',
                        style: TextStyle(
                            fontSize: AppTheme.fontSize(context, isSmall ? 18 : 22),
                            fontWeight: FontWeight.bold)),
                    Text('$_totalProducts items in inventory',
                        style: TextStyle(
                            fontSize: AppTheme.fontSize(context, isSmall ? 11 : 13),
                            color: AppTheme.secondaryText(context))),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(Currency.formatWhole(_totalValue),
                    style: TextStyle(
                        fontSize: AppTheme.fontSize(context, isSmall ? 13 : 15),
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryBright(context)),
                ),
              ),
            ],
          ),
        ),

        Padding(
          padding: EdgeInsets.fromLTRB(
              isSmall ? 12 : AppTheme.pad(context, 16), 0,
              isSmall ? 12 : AppTheme.pad(context, 16),
              isSmall ? 8 : AppTheme.pad(context, 8)),
          child: Row(
            children: [
              _statChip('$_inStock', 'In Stock', AppTheme.successBright(context)),
              const SizedBox(width: 8),
              _statChip('$_lowStock', 'Low', AppTheme.warningBright(context)),
              const SizedBox(width: 8),
              _statChip('$_outOfStock', 'Out', AppTheme.dangerBright(context)),
            ],
          ),
        ),

        Padding(
          padding: EdgeInsets.fromLTRB(
              isSmall ? 10 : AppTheme.pad(context, 16),
              isSmall ? 10 : AppTheme.pad(context, 12),
              isSmall ? 10 : AppTheme.pad(context, 16),
              0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search products...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: 12, vertical: isSmall ? 10 : 14),
                    filled: true,
                    fillColor: Theme.of(context).cardColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  style: TextStyle(
                      fontSize: AppTheme.fontSize(context, isSmall ? 13 : 15)),
                  onChanged: (v) {
                    _search = v;
                    _searchTimer?.cancel();
                    _searchTimer = Timer(const Duration(milliseconds: 350), () => _load());
                  },
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: _lowStockOnly
                      ? AppTheme.warning
                      : Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  onPressed: () {
                    _lowStockOnly = !_lowStockOnly;
                    _load();
                  },
                  icon: Icon(
                    Icons.warning_amber_rounded,
                    size: 20,
                    color: _lowStockOnly ? Colors.white : AppTheme.warning,
                  ),
                  tooltip: 'Low Stock',
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  onPressed: () => _showForm(),
                  icon: const Icon(Icons.add, size: 20, color: Colors.white),
                  tooltip: 'Add Product',
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _products.isEmpty
                  ? _emptyState()
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: isWide
                          ? _wideGrid(isSmall)
                          : _listView(isSmall),
                    ),
        ),
      ],
    );
  }

  Widget _statChip(String value, String label, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? color.withValues(alpha: 0.15) : color.withValues(alpha: 0.1);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: color, fontSize: 12)),
          const SizedBox(width: 3),
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.inventory_2_outlined,
                size: 56, color: AppTheme.primary.withValues(alpha: 0.4)),
          ),
          const SizedBox(height: 16),
          Text('No products found',
              style: TextStyle(
                  fontSize: AppTheme.fontSize(context, 18),
                  fontWeight: FontWeight.w600,                  color: AppTheme.secondaryText(context))),
                  const SizedBox(height: 6),
                  Text('Add your first product to get started',
              style: TextStyle(
                  fontSize: AppTheme.fontSize(context, 13),
                  color: AppTheme.secondaryText(context))),
        ],
      ),
    );
  }

  Widget _wideGrid(bool isSmall) {
    return GridView.builder(
      padding: EdgeInsets.all(AppTheme.pad(context, 12)),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 3.0,
      ),
      itemCount: _products.length,
      itemBuilder: (ctx, i) => _productCard(_products[i], isSmall),
    );
  }

  Widget _listView(bool isSmall) {
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(
          isSmall ? 8 : AppTheme.pad(context, 12),
          isSmall ? 4 : AppTheme.pad(context, 8),
          isSmall ? 8 : AppTheme.pad(context, 12),
          80),
      itemCount: _products.length,
      itemBuilder: (ctx, i) => _productCard(_products[i], isSmall),
    );
  }

  Widget _productCard(Product p, bool isSmall) {
    final isLow = p.totalStockPieces > 0 && p.totalStockPieces <= p.minimumStock;
    final out = p.totalStockPieces == 0;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showForm(product: p),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: isSmall ? 8 : 10, vertical: isSmall ? 6 : 8),
          child: Row(
            children: [

              Container(
                width: isSmall ? 32 : 36,
                height: isSmall ? 32 : 36,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: out
                        ? [Colors.red.shade400, Colors.red.shade600]
                        : isLow
                            ? [Colors.orange.shade300, Colors.orange.shade500]
                            : [AppTheme.success, Color(0xFF0D9E42)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Icon(
                    _categoryIcon(p.categoryName),
                    color: Colors.white,
                    size: isSmall ? 16 : 18,
                  ),
                ),
              ),
              SizedBox(width: isSmall ? 8 : 10),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(p.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: AppTheme.fontSize(context, isSmall ? 12 : 13))),
                    const SizedBox(height: 2),
                    Wrap(
                      spacing: 4,
                      runSpacing: 2,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (p.categoryName != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(p.categoryName!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: AppTheme.fontSize(context, 9),
                                    color: AppTheme.primaryBright(context),
                                    fontWeight: FontWeight.w500)),
                          ),
                        Text('${Currency.format(p.sellingPrice)}/pc',
                            style: TextStyle(
                                fontSize: AppTheme.fontSize(context, isSmall ? 10 : 11),
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryBright(context))),
                        if (p.sellsAsBox && p.boxSellingPrice != null)
                          Text('${Currency.format(p.boxSellingPrice!)}/box',
                              style: TextStyle(
                                  fontSize: AppTheme.fontSize(context, isSmall ? 10 : 11),
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.blueBright(context))),
                      ],
                    ),
                  ],
                ),
              ),

              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: out
                          ? AppTheme.danger.withValues(alpha: 0.1)
                          : isLow
                              ? AppTheme.warning.withValues(alpha: 0.1)
                              : AppTheme.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      out
                          ? 'Out'
                          : p.sellsAsBox
                              ? '${p.stockBoxes} bx${p.currentStock > 0 ? ', ${p.currentStock} pc' : ''}'
                              : '${p.totalStockPieces} pc',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: AppTheme.fontSize(context, isSmall ? 10 : 11),
                          color: out
                              ? AppTheme.dangerBright(context)
                              : isLow
                                  ? AppTheme.warningBright(context)
                                  : AppTheme.successBright(context)),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _actionBtn(Icons.add_circle_outline, () => _showRestockDialog(p), AppTheme.successBright(context), isSmall),
                      const SizedBox(width: 3),
                      _actionBtn(Icons.history, () => _showPriceHistory(p), AppTheme.warningBright(context), isSmall),
                      const SizedBox(width: 3),
                      _actionBtn(Icons.edit_outlined, () => _showForm(product: p), AppTheme.blueBright(context), isSmall),
                      const SizedBox(width: 3),
                      _actionBtn(Icons.delete_outline, () => _delete(p), AppTheme.dangerBright(context), isSmall),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionBtn(IconData icon, VoidCallback onTap, Color color, bool isSmall) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: EdgeInsets.all(isSmall ? 3 : 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: isSmall ? 13 : 14, color: color),
      ),
    );
  }

  IconData _categoryIcon(String? category) {
    if (category == null) return Icons.inventory_2;
    final lower = category.toLowerCase();
    if (lower.contains('electronic')) return Icons.devices;
    if (lower.contains('cloth') || lower.contains('fashion')) return Icons.checkroom;
    if (lower.contains('food') || lower.contains('beverage')) return Icons.restaurant;
    if (lower.contains('furniture')) return Icons.chair;
    if (lower.contains('book')) return Icons.menu_book;
    if (lower.contains('health') || lower.contains('beauty')) return Icons.spa;
    if (lower.contains('sport')) return Icons.sports_basketball;
    if (lower.contains('toy')) return Icons.toys;
    if (lower.contains('auto') || lower.contains('car')) return Icons.directions_car;
    return Icons.inventory_2;
  }

  Product? _findDuplicate(String name) {
    final n = name.trim().toLowerCase();
    if (n.isEmpty) return null;
    for (final p in _products) {
      if (p.name.trim().toLowerCase() == n) return p;
    }
    return null;
  }

  Widget _duplicateBanner(BuildContext dialogCtx, Product p) {
    return InkWell(
      onTap: () {
        Navigator.pop(dialogCtx); 
        _showRestockDialog(p);
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppTheme.warning.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.warning.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, size: 18, color: AppTheme.warning),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '"${p.name}" already exists (${p.sellsAsBox ? '${p.stockBoxes} box(es), ${p.currentStock} pc' : '${p.totalStockPieces} pc'}). Tap to add stock.',
                style: TextStyle(fontSize: 12, color: AppTheme.warning),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPriceHistory(Product p) {
    final history = p.priceHistory;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.history, color: AppTheme.warning, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Price History',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  Text(p.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12, color: AppTheme.secondaryText(context))),
                ],
              ),
            ),
          ],
        ),
        content: history.isEmpty
            ? Text('No price changes recorded yet.',
                style: TextStyle(fontSize: 13, color: AppTheme.secondaryText(context)))
            : SizedBox(
                width: 360,
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: history.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final h = history[i];
                    final dateStr =
                        DateFormat('MMM d, yyyy').format(h.changedAt.toLocal());
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: Icon(
                        i == history.length - 1
                            ? Icons.flag
                            : Icons.history_toggle_off,
                        size: 18,
                        color: i == history.length - 1
                            ? AppTheme.success
                            : AppTheme.secondaryText(context),
                      ),
                      title: Text(
                        h.unitsPerBox > 1 && h.boxCostPrice != null
                            ? '${Currency.format(h.boxCostPrice!)} → ${Currency.format(h.boxSellingPrice ?? 0)} / box (${Currency.format(h.costPrice)} → ${Currency.format(h.sellingPrice)} / pc)'
                            : '${Currency.format(h.costPrice)} → ${Currency.format(h.sellingPrice)} / pc',
                        style: const TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text('$dateStr • ${h.sourceLabel}',
                          style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.secondaryText(context))),
                    );
                  },
                ),
              ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  void _showRestockDialog(Product p) {
    final qtyCtrl = TextEditingController();
    final supplierCtrl = TextEditingController();
    final supplierPhoneCtrl = TextEditingController();
    final supplierEmailCtrl = TextEditingController();
    final invoiceCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    String unit = p.sellsAsBox ? 'box' : 'piece';

    String fmtPrice(num v) =>
        v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(2);
    final costCtrl = TextEditingController(
        text: unit == 'box'
            ? fmtPrice(p.boxCostPrice ?? (p.costPrice * p.unitsPerBox))
            : fmtPrice(p.costPrice));
    final sellPriceCtrl = TextEditingController(
        text: unit == 'box'
            ? fmtPrice(p.boxSellingPrice ?? (p.sellingPrice * p.unitsPerBox))
            : fmtPrice(p.sellingPrice));
    String paymentMethod = 'cash';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.add_shopping_cart, color: AppTheme.success, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Add Stock',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                    Text(p.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12, color: AppTheme.secondaryText(context))),
                  ],
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.success.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  p.sellsAsBox
                      ? 'Current stock: ${p.stockBoxes} box(es), ${p.currentStock} pc'
                      : 'Current stock: ${p.totalStockPieces} pc',
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.success),
                ),
              ),
              if (p.priceHistory.length > 1) ...[
                const SizedBox(height: 6),
                Text(
                  'Last price change: ${DateFormat('MMM d, yyyy').format(p.priceHistory.last.changedAt.toLocal())} — leaving the pre-filled prices unchanged keeps this batch at the current prices.',
                  style: TextStyle(
                      fontSize: 10.5, color: AppTheme.secondaryText(context)),
                ),
              ],
              const SizedBox(height: 12),
              if (p.sellsAsBox) ...[
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Boxes'),
                        selected: unit == 'box',
                        onSelected: (_) => setDialogState(() {
                          unit = 'box';
                          costCtrl.text = fmtPrice(p.boxCostPrice ?? (p.costPrice * p.unitsPerBox));
                          sellPriceCtrl.text = fmtPrice(p.boxSellingPrice ?? (p.sellingPrice * p.unitsPerBox));
                        }),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Pieces'),
                        selected: unit == 'piece',
                        onSelected: (_) => setDialogState(() {
                          unit = 'piece';
                          costCtrl.text = fmtPrice(p.costPrice);
                          sellPriceCtrl.text = fmtPrice(p.sellingPrice);
                        }),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: qtyCtrl,
                autofocus: true,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Quantity to add (${unit == 'box' ? 'boxes' : 'pieces'}) *',
                  filled: true,
                  fillColor: Theme.of(context).scaffoldBackgroundColor,
                ),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Icon(Icons.local_shipping, size: 14, color: AppTheme.success),
                  const SizedBox(width: 6),
                  Text('Supplier & Purchase Info',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.success)),
                  const SizedBox(width: 4),
                  Text('* Supplier required',
                      style: TextStyle(fontSize: 10, color: AppTheme.secondaryText(context))),
                ],
              ),
              const SizedBox(height: 12),
              _field(supplierCtrl, 'Supplier Company *'),
              const SizedBox(height: 12),
              _field(supplierPhoneCtrl, 'Supplier Phone', keyboardType: TextInputType.phone),
              const SizedBox(height: 12),
              _field(supplierEmailCtrl, 'Supplier Email', keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 12),
              _field(costCtrl,
                  unit == 'box' ? 'Buying Price (per box) *' : 'Buying Price (per piece) *',
                  keyboardType: TextInputType.number),
              const SizedBox(height: 12),
              _field(sellPriceCtrl,
                  unit == 'box' ? 'Selling Price (per box) *' : 'Selling Price (per piece) *',
                  keyboardType: TextInputType.number),
              const SizedBox(height: 12),
              _field(invoiceCtrl, 'Invoice Number'),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Payment Method'),
                value: paymentMethod,
                items: const [
                  DropdownMenuItem(value: 'cash', child: Text('Cash')),
                  DropdownMenuItem(value: 'credit', child: Text('Credit')),
                  DropdownMenuItem(value: 'bank_transfer', child: Text('Bank Transfer')),
                  DropdownMenuItem(value: 'mobile_money', child: Text('Mobile Money')),
                  DropdownMenuItem(value: 'other', child: Text('Other')),
                ],
                onChanged: (v) => setDialogState(() => paymentMethod = v ?? 'cash'),
              ),
              const SizedBox(height: 12),
              _field(notesCtrl, 'Notes'),
            ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => _submitRestock(
                  ctx,
                  p,
                  qtyCtrl,
                  unit,
                  supplierCtrl: supplierCtrl,
                  supplierPhoneCtrl: supplierPhoneCtrl,
                  supplierEmailCtrl: supplierEmailCtrl,
                  invoiceCtrl: invoiceCtrl,
                  notesCtrl: notesCtrl,
                  costCtrl: costCtrl,
                  sellPriceCtrl: sellPriceCtrl,
                  paymentMethod: paymentMethod),
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitRestock(
    BuildContext ctx,
    Product p,
    TextEditingController qtyCtrl,
    String unit, {
    required TextEditingController supplierCtrl,
    required TextEditingController supplierPhoneCtrl,
    required TextEditingController supplierEmailCtrl,
    required TextEditingController invoiceCtrl,
    required TextEditingController notesCtrl,
    required TextEditingController costCtrl,
    required TextEditingController sellPriceCtrl,
    required String paymentMethod,
  }) async {
    final qty = int.tryParse(qtyCtrl.text) ?? 0;
    if (qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Enter a quantity greater than 0.'),
          backgroundColor: AppTheme.danger));
      return;
    }

    if (supplierCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Supplier company is required.'),
          backgroundColor: AppTheme.danger));
      return;
    }
    final buyPrice = double.tryParse(costCtrl.text);
    if (buyPrice == null || buyPrice < 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Enter the buying price for this batch.'),
          backgroundColor: AppTheme.danger));
      return;
    }
    final sellPrice = double.tryParse(sellPriceCtrl.text);
    if (sellPrice == null || sellPrice < 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Enter the selling price for this batch.'),
          backgroundColor: AppTheme.danger));
      return;
    }
    try {

      await ApiService.createProduct({
        'name': p.name,
        'categoryId': p.categoryId,
        'minimumStock': p.minimumStock,
        'sellingUnit': unit,
        'unitsPerBox': p.unitsPerBox,
        'stockBoxes': unit == 'box' ? qty : 0,
        'currentStock': unit == 'piece' ? qty : 0,
        'purchaseUnit': unit,

        'costPrice': buyPrice,
        'sellingPrice': sellPrice,
        'batchCostPrice': buyPrice,
        'batchSellingPrice': sellPrice,
        'supplier': supplierCtrl.text.trim(),
        'supplierPhone': supplierPhoneCtrl.text.trim().isNotEmpty
            ? supplierPhoneCtrl.text.trim()
            : null,
        'supplierEmail': supplierEmailCtrl.text.trim().isNotEmpty
            ? supplierEmailCtrl.text.trim()
            : null,
        'invoiceNumber': invoiceCtrl.text.trim().isNotEmpty ? invoiceCtrl.text.trim() : null,
        'paymentMethod': paymentMethod,
        'notes': notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : null,
      });
      if (ctx.mounted) {
        Navigator.pop(ctx);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Stock updated: +$qty ${unit == 'box' ? 'box(es)' : 'piece(s)'} of ${p.name} — purchase recorded'),
            backgroundColor: AppTheme.success));
      }

      AppEvents.instance.emit('purchases');
      AppEvents.instance.emit('products'); 
    } catch (e) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.toString()), backgroundColor: AppTheme.danger));
      }
    }
  }

  void _showForm({Product? product}) {
    final isEditing = product != null;
    final nameCtrl = TextEditingController(text: product?.name ?? '');
    final costCtrl = TextEditingController(text: product?.costPrice.toString() ?? '');
    final priceCtrl = TextEditingController(text: product?.sellingPrice.toString() ?? '');
    final stockCtrl = TextEditingController(text: product?.currentStock.toString() ?? '0');
    final minCtrl = TextEditingController(text: product?.minimumStock.toString() ?? '5');
    final unitsPerBoxCtrl = TextEditingController(text: product?.unitsPerBox.toString() ?? '1');
    final stockBoxesCtrl = TextEditingController(text: product?.stockBoxes.toString() ?? '0');
    final boxCostCtrl = TextEditingController(text: product?.boxCostPrice?.toString() ?? '');
    final boxPriceCtrl = TextEditingController(text: product?.boxSellingPrice?.toString() ?? '');

    final supplierCtrl = TextEditingController();
    final supplierPhoneCtrl = TextEditingController();
    final supplierEmailCtrl = TextEditingController();
    final invoiceCtrl = TextEditingController();
    final purchaseNotesCtrl = TextEditingController();
    String paymentMethod = 'cash';

    String sellingUnit = product?.sellingUnit ?? 'piece';
    String? selectedCategoryId = product?.categoryId;
    Product? duplicate;

    void recalcPieces() {
      final boxes = int.tryParse(stockBoxesCtrl.text) ?? 0;
      final upb = int.tryParse(unitsPerBoxCtrl.text) ?? 1;
      stockCtrl.text = (boxes * upb).toString();
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(isEditing ? Icons.edit : Icons.add, color: AppTheme.primary, size: 20),
              ),
              const SizedBox(width: 10),
              Text(isEditing ? 'Edit Product' : 'Add Product',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [

                _field(nameCtrl, 'Product Name *',
                    onChanged: (v) => setDialogState(() => duplicate = _findDuplicate(v))),
                if (!isEditing && duplicate != null) ...[
                  const SizedBox(height: 10),
                  _duplicateBanner(ctx, duplicate!),
                ],
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Category'),
                  value: selectedCategoryId,
                  items: _categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                  onChanged: (v) => setDialogState(() => selectedCategoryId = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Selling Unit'),
                  value: sellingUnit,
                  items: const [
                    DropdownMenuItem(value: 'piece', child: Text('Piece')),
                    DropdownMenuItem(value: 'box', child: Text('Box')),
                  ],
                  onChanged: (v) {
                    setDialogState(() {
                      sellingUnit = v ?? 'piece';
                      if (sellingUnit == 'box') recalcPieces();
                    });
                  },
                ),
                if (sellingUnit != 'piece') ...[
                  const SizedBox(height: 12),
                  _field(unitsPerBoxCtrl, 'Units Per Box',
                      keyboardType: TextInputType.number,
                      onChanged: (_) { setDialogState(() {}); recalcPieces(); }),
                ],
                const SizedBox(height: 12),
                _field(costCtrl, 'Cost Price (per piece)', keyboardType: TextInputType.number),
                const SizedBox(height: 12),
                _field(priceCtrl, 'Selling Price (per piece)', keyboardType: TextInputType.number),
                if (sellingUnit != 'piece') ...[
                  const SizedBox(height: 12),
                  _field(boxCostCtrl, 'Box Cost Price', keyboardType: TextInputType.number),
                  const SizedBox(height: 12),
                  _field(boxPriceCtrl, 'Box Selling Price', keyboardType: TextInputType.number),
                  const SizedBox(height: 12),
                  _field(stockBoxesCtrl, 'Stock (Boxes)',
                      keyboardType: TextInputType.number,
                      onChanged: (_) { setDialogState(() {}); recalcPieces(); }),
                ],
                const SizedBox(height: 12),
                _field(stockCtrl,
                    sellingUnit == 'box' ? 'Stock (Auto: Boxes × Units/Box)' : 'Stock (Pieces)',
                    keyboardType: TextInputType.number, readOnly: sellingUnit == 'box'),
                const SizedBox(height: 12),
                _field(minCtrl, 'Min Stock', keyboardType: TextInputType.number),

                if (!isEditing) ...[
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.success.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('Supplier & Purchase Info (Optional)',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.success)),
                  ),
                  const SizedBox(height: 12),
                  _field(supplierCtrl, 'Supplier Company'),
                  const SizedBox(height: 12),
                  _field(supplierPhoneCtrl, 'Supplier Phone', keyboardType: TextInputType.phone),
                  const SizedBox(height: 12),
                  _field(supplierEmailCtrl, 'Supplier Email', keyboardType: TextInputType.emailAddress),
                  const SizedBox(height: 12),
                  _field(invoiceCtrl, 'Invoice Number'),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Payment Method'),
                    value: paymentMethod,
                    items: const [
                      DropdownMenuItem(value: 'cash', child: Text('Cash')),
                      DropdownMenuItem(value: 'credit', child: Text('Credit')),
                      DropdownMenuItem(value: 'bank_transfer', child: Text('Bank Transfer')),
                      DropdownMenuItem(value: 'mobile_money', child: Text('Mobile Money')),
                      DropdownMenuItem(value: 'other', child: Text('Other')),
                    ],
                    onChanged: (v) => setDialogState(() => paymentMethod = v ?? 'cash'),
                  ),
                  const SizedBox(height: 12),
                  _field(purchaseNotesCtrl, 'Purchase Notes'),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Product name is required.'), backgroundColor: AppTheme.danger));
                  return;
                }
                if (selectedCategoryId == null || selectedCategoryId!.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Please select a category.'), backgroundColor: AppTheme.danger));
                  return;
                }
                if (double.tryParse(costCtrl.text) == null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Valid cost price is required.'), backgroundColor: AppTheme.danger));
                  return;
                }
                if (double.tryParse(priceCtrl.text) == null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Valid selling price is required.'), backgroundColor: AppTheme.danger));
                  return;
                }
                final data = {
                  'name': nameCtrl.text.trim(),
                  'categoryId': selectedCategoryId!,
                  'costPrice': double.tryParse(costCtrl.text) ?? 0,
                  'sellingPrice': double.tryParse(priceCtrl.text) ?? 0,
                  'minimumStock': int.tryParse(minCtrl.text) ?? 5,
                  'sellingUnit': sellingUnit,
                  'unitsPerBox': int.tryParse(unitsPerBoxCtrl.text) ?? 1,
                  'stockBoxes': int.tryParse(stockBoxesCtrl.text) ?? 0,
                  'currentStock': sellingUnit == 'box' ? 0 : (int.tryParse(stockCtrl.text) ?? 0),
                  'boxCostPrice': double.tryParse(boxCostCtrl.text) ?? 0,
                  'boxSellingPrice': double.tryParse(boxPriceCtrl.text) ?? 0,
                };
                bool merged = false;
                try {
                  if (isEditing) {
                    await ApiService.updateProduct(product!.id, data);
                  } else {

                    final sendData = Map<String, dynamic>.from(data);
                    sendData['supplier'] = supplierCtrl.text.isNotEmpty ? supplierCtrl.text : null;
                    sendData['supplierPhone'] = supplierPhoneCtrl.text.isNotEmpty ? supplierPhoneCtrl.text : null;
                    sendData['supplierEmail'] = supplierEmailCtrl.text.isNotEmpty ? supplierEmailCtrl.text : null;
                    sendData['invoiceNumber'] = invoiceCtrl.text.isNotEmpty ? invoiceCtrl.text : null;
                    sendData['paymentMethod'] = paymentMethod;
                    sendData['notes'] = purchaseNotesCtrl.text.isNotEmpty ? purchaseNotesCtrl.text : null;

                    final res = await ApiService.createProduct(sendData);
                    merged = res['merged'] == true;

                    if (!merged) {
                      final newProduct = res['product'];
                      final qty = sellingUnit == 'box'
                          ? (int.tryParse(stockBoxesCtrl.text) ?? 0)
                          : (int.tryParse(stockCtrl.text) ?? 0);

                      if (qty > 0 && newProduct != null) {
                        final unitCost = sellingUnit == 'box'
                            ? (double.tryParse(boxCostCtrl.text) ?? 0)
                            : (double.tryParse(costCtrl.text) ?? 0);
                        try {
                          await ApiService.createPurchase({
                            'productId': newProduct['_id'],
                            'quantity': qty,
                            'purchaseUnit': sellingUnit,
                            'unitCost': unitCost,
                            'supplier': supplierCtrl.text.isNotEmpty ? supplierCtrl.text : null,
                            'supplierPhone': supplierPhoneCtrl.text.isNotEmpty ? supplierPhoneCtrl.text : null,
                            'supplierEmail': supplierEmailCtrl.text.isNotEmpty ? supplierEmailCtrl.text : null,
                            'invoiceNumber': invoiceCtrl.text.isNotEmpty ? invoiceCtrl.text : null,
                            'paymentMethod': paymentMethod,
                            'notes': purchaseNotesCtrl.text.isNotEmpty ? purchaseNotesCtrl.text : null,
                          });
                        } catch (pErr) {

                          debugPrint('Purchase record failed: $pErr');
                        }
                      }
                    }
                  }
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    final msg = merged
                        ? 'Stock updated — product already exists.'
                        : 'Product created.';
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(msg), backgroundColor: AppTheme.success));
                  }

                  AppEvents.instance.emit('purchases');
                  AppEvents.instance.emit('products');
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(e.toString()), backgroundColor: AppTheme.danger));
                  }
                }
              },
              child: Text(isEditing ? 'Update' : 'Create'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label,
      {TextInputType? keyboardType, bool readOnly = false, Function(String)? onChanged}) {
    return TextField(
      controller: ctrl,
      readOnly: readOnly,
      keyboardType: keyboardType,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Theme.of(context).scaffoldBackgroundColor,
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
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirm == true) {
      await ApiService.deleteProduct(p.id);

      AppEvents.instance.emit('products');
    }
  }
}