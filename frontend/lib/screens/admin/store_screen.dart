import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/app_events.dart';
import '../../models/product.dart';
import '../../models/category.dart';
import '../../utils/theme.dart';
import '../../utils/currency.dart';

class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key});
  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  List<Product> _products = [];
  List<Category> _categories = [];
  bool _loading = true;
  String _search = '';
  String? _selectedCategoryId; 
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

  List<Product> get _filtered {
    if (_selectedCategoryId == null) return _products;
    return _products.where((p) => p.categoryId == _selectedCategoryId).toList();
  }

  int get _totalStock => _filtered.fold(0, (s, p) => s + p.totalStockPieces);
  double get _totalValue =>
      _filtered.fold(0.0, (s, p) => s + (p.sellingPrice * p.totalStockPieces));
  int get _totalBoxes =>
      _filtered.fold(0, (s, p) => s + (p.sellsAsBox ? p.stockBoxes : 0));

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
              isSmall ? 4 : AppTheme.pad(context, 4)),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Store',
                        style: TextStyle(
                            fontSize: AppTheme.fontSize(context, isSmall ? 18 : 22),
                            fontWeight: FontWeight.bold)),
                    Text(
                        '${_filtered.length} items • $_totalBoxes bx • $_totalStock pcs • ${Currency.formatWhole(_totalValue)}',
                        style: TextStyle(
                            fontSize: AppTheme.fontSize(context, isSmall ? 11 : 13),
                            color: AppTheme.secondaryText(context))),
                  ],
                ),
              ),
            ],
          ),
        ),

        Padding(
          padding: EdgeInsets.fromLTRB(
              isSmall ? 10 : AppTheme.pad(context, 16),
              isSmall ? 6 : AppTheme.pad(context, 8),
              isSmall ? 10 : AppTheme.pad(context, 16),
              0),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search store...',
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
            style: TextStyle(fontSize: AppTheme.fontSize(context, isSmall ? 13 : 15)),
            onChanged: (v) {
              _search = v;
              _searchTimer?.cancel();
              _searchTimer = Timer(const Duration(milliseconds: 350), () => _load());
            },
          ),
        ),

        Padding(
          padding: EdgeInsets.fromLTRB(
              isSmall ? 10 : AppTheme.pad(context, 16),
              isSmall ? 6 : AppTheme.pad(context, 8),
              isSmall ? 10 : AppTheme.pad(context, 16),
              0),
          child: SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _catChip('All', null),
                for (final cat in _categories) _catChip(cat.name, cat.id),
              ],
            ),
          ),
        ),

        const SizedBox(height: 6),

        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _filtered.isEmpty
                  ? RefreshIndicator(
                      onRefresh: _load,
                      child: LayoutBuilder(
                        builder: (context, constraints) => ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(height: constraints.maxHeight * 0.35),
                            _emptyState(),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: isWide ? _wideGrid(isSmall) : _listView(isSmall),
                    ),
        ),
      ],
    );
  }

  Widget _catChip(String label, String? catId) {
    final isActive = _selectedCategoryId == catId;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label, style: TextStyle(fontSize: 12)),
        selected: isActive,
        selectedColor: AppTheme.primary,
        backgroundColor: Theme.of(context).cardColor,
        labelStyle: TextStyle(
            color: isActive ? Colors.white : AppTheme.secondaryText(context),
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400),
        side: BorderSide(
          color: isActive
              ? AppTheme.primary
              : Theme.of(context).dividerColor.withValues(alpha: 0.2),
        ),
        onSelected: (_) {
          setState(() => _selectedCategoryId = catId);
        },
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
            child: Icon(Icons.storefront_outlined,
                size: 56, color: AppTheme.primary.withValues(alpha: 0.4)),
          ),
          const SizedBox(height: 16),
          Text('No products in store',
              style: TextStyle(
                  fontSize: AppTheme.fontSize(context, 18),
                  fontWeight: FontWeight.w600,
                  color: AppTheme.secondaryText(context))),
          const SizedBox(height: 6),
          Text('Add products from the Stock section',
              style: TextStyle(
                  fontSize: AppTheme.fontSize(context, 13),
                  color: AppTheme.secondaryText(context))),
        ],
      ),
    );
  }

  Widget _wideGrid(bool isSmall) {
    return GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.all(AppTheme.pad(context, 12)),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 2.8,
      ),
      itemCount: _filtered.length,
      itemBuilder: (ctx, i) => _productCard(_filtered[i], isSmall),
    );
  }

  Widget _listView(bool isSmall) {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
          isSmall ? 8 : AppTheme.pad(context, 12),
          isSmall ? 4 : AppTheme.pad(context, 8),
          isSmall ? 8 : AppTheme.pad(context, 12),
          80),
      itemCount: _filtered.length,
      itemBuilder: (ctx, i) => _productCard(_filtered[i], isSmall),
    );
  }

  Widget _productCard(Product p, bool isSmall) {
    final isLow = p.totalStockPieces > 0 && p.totalStockPieces <= p.minimumStock;
    final out = p.totalStockPieces == 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showDetails(p),
        child: Padding(
          padding: EdgeInsets.symmetric(
              horizontal: isSmall ? 10 : 12, vertical: isSmall ? 8 : 10),
          child: Row(
            children: [

              Container(
                width: isSmall ? 36 : 40,
                height: isSmall ? 36 : 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: out
                        ? [Colors.red.shade400, Colors.red.shade600]
                        : isLow
                            ? [Colors.orange.shade300, Colors.orange.shade500]
                            : [AppTheme.success, const Color(0xFF0D9E42)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Icon(
                    _categoryIcon(p.categoryName),
                    color: Colors.white,
                    size: isSmall ? 17 : 19,
                  ),
                ),
              ),
              SizedBox(width: isSmall ? 10 : 12),

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
                            fontSize: AppTheme.fontSize(context, isSmall ? 13 : 14))),
                    const SizedBox(height: 3),
                    Wrap(
                      spacing: 6,
                      runSpacing: 2,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (p.categoryName != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(p.categoryName!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: AppTheme.fontSize(context, 10),
                                    color: AppTheme.primaryBright(context),
                                    fontWeight: FontWeight.w500)),
                          ),
                        Text('${Currency.format(p.sellingPrice)}/pc',
                            style: TextStyle(
                                fontSize: AppTheme.fontSize(context, isSmall ? 11 : 12),
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryBright(context))),
                        if (p.sellsAsBox && p.boxSellingPrice != null)
                          Text('${Currency.format(p.boxSellingPrice!)}/box',
                              style: TextStyle(
                                  fontSize: AppTheme.fontSize(context, isSmall ? 11 : 12),
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.blueBright(context))),
                      ],
                    ),
                  ],
                ),
              ),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: out
                      ? AppTheme.danger.withValues(alpha: 0.1)
                      : isLow
                          ? AppTheme.warning.withValues(alpha: 0.1)
                          : AppTheme.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  out
                      ? 'Out of Stock'
                      : p.sellsAsBox
                          ? '${p.stockBoxes} bx${p.currentStock > 0 ? ', ${p.currentStock} pc' : ''}'
                          : '${p.totalStockPieces} pcs',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: AppTheme.fontSize(context, isSmall ? 11 : 12),
                      color: out
                          ? AppTheme.dangerBright(context)
                          : isLow
                              ? AppTheme.warningBright(context)
                              : AppTheme.successBright(context)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetails(Product p) {
    final isLow = p.totalStockPieces > 0 && p.totalStockPieces <= p.minimumStock;
    final out = p.totalStockPieces == 0;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(p.name,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            if (p.categoryName != null) ...[
              const SizedBox(height: 4),
              Text(p.categoryName!,
                  style: TextStyle(fontSize: 13, color: AppTheme.secondaryText(context))),
            ],
            const SizedBox(height: 16),
            _detailRow('Selling Price', '${Currency.format(p.sellingPrice)}/pc'),
            _detailRow('Cost Price', '${Currency.format(p.costPrice)}/pc'),
            if (p.sellsAsBox && p.boxSellingPrice != null)
              _detailRow('Box Selling Price', '${Currency.format(p.boxSellingPrice!)}/box'),
            if (p.sellsAsBox && p.boxCostPrice != null)
              _detailRow('Box Cost Price', '${Currency.format(p.boxCostPrice!)}/box'),
            const Divider(height: 20),
            _detailRow('Total Stock', '${p.totalStockPieces} pcs'),
            if (p.sellsAsBox) ...[
              _detailRow('Full Boxes', '${p.stockBoxes}'),
              _detailRow('Loose Pieces', '${p.currentStock}'),
              _detailRow('Units per Box', '${p.unitsPerBox}'),
            ],
            _detailRow('Minimum Stock', '${p.minimumStock} pcs'),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: out
                    ? AppTheme.danger.withValues(alpha: 0.1)
                    : isLow
                        ? AppTheme.warning.withValues(alpha: 0.1)
                        : AppTheme.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                out ? 'Out of Stock' : isLow ? 'Low Stock' : 'In Stock',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: out
                        ? AppTheme.dangerBright(context)
                        : isLow
                            ? AppTheme.warningBright(context)
                            : AppTheme.successBright(context)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 13, color: AppTheme.secondaryText(context))),
          Text(value,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  IconData _categoryIcon(String? category) {
    if (category == null) return Icons.storefront;
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
    return Icons.storefront;
  }
}