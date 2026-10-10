import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../services/app_events.dart';
import '../../models/product.dart';
import '../../models/category.dart';
import '../../utils/theme.dart';
import '../../utils/currency.dart';
import '../../widgets/compact_data_table.dart';

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
  DateTime? _selectedPurchaseDate;
  Timer? _searchTimer;

  @override
  void initState() {
    super.initState();
    _load();

    AppEvents.instance.subscribe(_onEvent);
  }

  void _onEvent(String event) {
    if (!mounted) return;

    final globalQuery = AppEvents.globalSearchQuery(event);
    if (globalQuery != null) {
      _search = globalQuery;
      _searchTimer?.cancel();
      _load(silent: true);
    } else if (event == 'products') {
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
          purchaseDate: _selectedPurchaseDate == null
              ? null
              : DateFormat('yyyy-MM-dd').format(_selectedPurchaseDate!),
        ),
        ApiService.getCategories(),
      ]);
      final res = results[0];
      final catRes = results[1];
      final list = (res['products'] as List)
          .map((p) => Product.fromJson(p))
          .toList();
      final cats = (catRes['categories'] as List)
          .map((c) => Category.fromJson(c))
          .toList();
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

  Future<void> _pickAddedDate() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedPurchaseDate ?? today,
      firstDate: DateTime(2020),
      lastDate: today,
      helpText: 'Select product purchase date',
    );
    if (picked == null || !mounted) return;
    setState(() => _selectedPurchaseDate = picked);
    _load();
  }

  int get _totalStock => _filtered.fold(0, (s, p) => s + p.totalStockPieces);
  double get _inventoryValue => _filtered.fold(
    0.0,
    (sum, product) =>
        sum +
        product.currentStock * product.costPrice +
        product.stockBoxes *
            (product.boxCostPrice ?? product.costPrice * product.unitsPerBox),
  );
  int get _totalBoxes =>
      _filtered.fold(0, (s, p) => s + (p.sellsAsBox ? p.stockBoxes : 0));

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmall = size.height < 600 || size.width < 400;

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            isSmall ? 12 : AppTheme.pad(context, 16),
            isSmall ? 12 : AppTheme.pad(context, 16),
            isSmall ? 12 : AppTheme.pad(context, 16),
            isSmall ? 4 : AppTheme.pad(context, 4),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Store',
                      style: TextStyle(
                        fontSize: AppTheme.fontSize(context, isSmall ? 18 : 22),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${_filtered.length} items • $_totalBoxes bx • $_totalStock pcs',
                      style: TextStyle(
                        fontSize: AppTheme.fontSize(context, isSmall ? 11 : 13),
                        color: AppTheme.secondaryText(context),
                      ),
                    ),
                    Text(
                      'Inventory value (at cost): ${Currency.formatWhole(_inventoryValue)}',
                      style: TextStyle(
                        fontSize: AppTheme.fontSize(context, isSmall ? 11 : 13),
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryBright(context),
                      ),
                    ),
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
            0,
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search store...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: isSmall ? 10 : 14,
                    ),
                    filled: true,
                    fillColor: Theme.of(context).cardColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  style: TextStyle(
                    fontSize: AppTheme.fontSize(context, isSmall ? 13 : 15),
                  ),
                  onChanged: (v) {
                    _search = v;
                    _searchTimer?.cancel();
                    _searchTimer = Timer(
                      const Duration(milliseconds: 350),
                      () => _load(),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () {
                  _searchTimer?.cancel();
                  _load();
                },
                icon: const Icon(Icons.search),
                label: const Text('Search'),
              ),
            ],
          ),
        ),

        Padding(
          padding: EdgeInsets.fromLTRB(
            isSmall ? 10 : AppTheme.pad(context, 16),
            isSmall ? 6 : AppTheme.pad(context, 8),
            isSmall ? 10 : AppTheme.pad(context, 16),
            0,
          ),
          child: SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _purchaseDateChip(),
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
              : RefreshIndicator(onRefresh: _load, child: _storeTable()),
        ),
      ],
    );
  }

  Widget _purchaseDateChip() {
    final selected = _selectedPurchaseDate;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InputChip(
        avatar: const Icon(Icons.calendar_today, size: 16),
        label: Text(
          selected == null
              ? 'Bought date'
              : DateFormat('MMM d, yyyy').format(selected),
          style: const TextStyle(fontSize: 12),
        ),
        selected: selected != null,
        selectedColor: AppTheme.primary.withValues(alpha: 0.12),
        onPressed: _pickAddedDate,
        onDeleted: selected == null
            ? null
            : () {
                setState(() => _selectedPurchaseDate = null);
                _load();
              },
      ),
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
          fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
        ),
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
            child: Icon(
              Icons.storefront_outlined,
              size: 56,
              color: AppTheme.primary.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No products in store',
            style: TextStyle(
              fontSize: AppTheme.fontSize(context, 18),
              fontWeight: FontWeight.w600,
              color: AppTheme.secondaryText(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Add products from the Stock section',
            style: TextStyle(
              fontSize: AppTheme.fontSize(context, 13),
              color: AppTheme.secondaryText(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _storeTable() {
    final rows = <CompactDataRow>[];

    for (final product in _filtered) {
      final isLow =
          product.totalStockPieces > 0 &&
          product.totalStockPieces <= product.minimumStock;
      final out = product.totalStockPieces == 0;
      final stock = product.sellsAsBox
          ? '${product.stockBoxes} bx${product.currentStock > 0 ? ', ${product.currentStock} pc' : ''}'
          : '${product.totalStockPieces} pcs';

      rows.add(
        CompactDataRow([
          CompactDataTable.accent(context, product.name),
          CompactDataTable.muted(context, product.categoryName ?? '—'),
          CompactDataTable.cell(context, stock),
          CompactDataTable.cell(
            context,
            '${Currency.format(product.sellingPrice)}/pc',
          ),
          CompactDataTable.cell(
            context,
            product.sellsAsBox && product.boxSellingPrice != null
                ? '${Currency.format(product.boxSellingPrice!)}/box'
                : '—',
          ),
          CompactDataTable.chip(
            context,
            out
                ? 'Out of stock'
                : isLow
                ? 'Low stock'
                : 'In stock',
            out
                ? AppTheme.dangerBright(context)
                : isLow
                ? AppTheme.warningBright(context)
                : AppTheme.successBright(context),
          ),
        ], onTap: () => _showDetails(product)),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: CompactDataTable(
        columns: const [
          CompactTableColumn('Item Name', flex: 3),
          CompactTableColumn('Category', flex: 2),
          CompactTableColumn('Stock', flex: 2),
          CompactTableColumn('Piece Price', flex: 2),
          CompactTableColumn('Box Price', flex: 2),
          CompactTableColumn('Status', flex: 2),
        ],
        rows: rows,
      ),
    );
  }

  void _showDetails(Product p) {
    final isLow =
        p.totalStockPieces > 0 && p.totalStockPieces <= p.minimumStock;
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
            Text(
              p.name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            if (p.categoryName != null) ...[
              const SizedBox(height: 4),
              Text(
                p.categoryName!,
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.secondaryText(context),
                ),
              ),
            ],
            const SizedBox(height: 16),
            _detailRow(
              'Selling Price',
              '${Currency.format(p.sellingPrice)}/pc',
            ),
            _detailRow('Cost Price', '${Currency.format(p.costPrice)}/pc'),
            if (p.sellsAsBox && p.boxSellingPrice != null)
              _detailRow(
                'Box Selling Price',
                '${Currency.format(p.boxSellingPrice!)}/box',
              ),
            if (p.sellsAsBox && p.boxCostPrice != null)
              _detailRow(
                'Box Cost Price',
                '${Currency.format(p.boxCostPrice!)}/box',
              ),
            const Divider(height: 20),
            _detailRow('Total Stock', '${p.totalStockPieces} pcs'),
            if (p.sellsAsBox) ...[
              _detailRow('Full Boxes', '${p.stockBoxes}'),
              _detailRow('Loose Pieces', '${p.currentStock}'),
              _detailRow('Units per Box', '${p.unitsPerBox}'),
            ],
            _detailRow('Minimum Stock', '${p.minimumStock} pcs'),
            if (p.createdAt != null)
              _detailRow(
                'Added',
                DateFormat('MMM d, yyyy').format(p.createdAt!.toLocal()),
              ),
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
                out
                    ? 'Out of Stock'
                    : isLow
                    ? 'Low Stock'
                    : 'In Stock',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: out
                      ? AppTheme.dangerBright(context)
                      : isLow
                      ? AppTheme.warningBright(context)
                      : AppTheme.successBright(context),
                ),
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
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.secondaryText(context),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
