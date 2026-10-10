import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../services/app_events.dart';
import '../../models/sale.dart';
import '../../models/product.dart';
import '../../widgets/compact_data_table.dart';
import '../../widgets/loading_button.dart';
import '../../widgets/searchable_picker.dart';
import '../../widgets/section_search_bar.dart';
import '../../utils/theme.dart';
import '../../utils/currency.dart';
import '../../widgets/period_filter_chip.dart';
import '../../services/auth_provider.dart';
import 'package:provider/provider.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});
  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  List<Sale> _sales = [];
  List<Product> _products = [];
  bool _loading = true;
  bool _showAll = false;
  String _searchQuery = '';

  DateTime? _startDate;
  DateTime? _endDate;

  DateTime get _safeStart => _startDate ?? _today();
  DateTime get _safeEnd => _endDate ?? _today();

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

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
      setState(() => _searchQuery = globalQuery);
    } else if (event == 'products') {
      _load(silent: true);
    } else if (event == 'sales') {
      _load(silent: true);
    }
  }

  @override
  void dispose() {
    AppEvents.instance.unsubscribe(_onEvent);
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      String? startStr;
      String? endStr;
      if (!_showAll) {
        final startUtc = DateTime(
          _safeStart.year,
          _safeStart.month,
          _safeStart.day,
        ).toUtc();
        final endUtc = DateTime(
          _safeEnd.year,
          _safeEnd.month,
          _safeEnd.day,
          23,
          59,
          59,
          999,
        ).toUtc();
        startStr = startUtc.toIso8601String();
        endStr = endUtc.toIso8601String();
      }
      final results = await Future.wait([
        ApiService.getSales(startDate: startStr, endDate: endStr),
        ApiService.getProducts(),
      ]);
      final salesRes = results[0];
      final prodRes = results[1];
      setState(() {
        _sales = (salesRes['sales'] as List)
            .map((s) => Sale.fromJson(s))
            .toList();
        _products = (prodRes['products'] as List)
            .map((p) => Product.fromJson(p))
            .toList();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  void _showToday() {
    final today = _today();
    setState(() {
      _showAll = false;
      _startDate = today;
      _endDate = today;
    });
    _load();
  }

  void _showAllSales() {
    setState(() {
      _showAll = true;
    });
    _load();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final today = _today();
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _safeStart : _safeEnd,
      firstDate: DateTime(2020),
      lastDate: today,
    );
    if (picked != null) {
      setState(() {
        _showAll = false;
        if (isStart) {
          _startDate = picked;
          if (_safeEnd.isBefore(picked)) _endDate = picked;
        } else {
          _endDate = picked;
          if (_safeStart.isAfter(picked)) _startDate = picked;
        }
      });
      _load();
    }
  }

  String _formatDateLabel(DateTime d) => DateFormat('MMM d, yyyy').format(d);

  @override
  Widget build(BuildContext context) {
    final approvedSales = _sales.where((sale) => sale.status == 'approved');
    final totalRev = approvedSales.fold(0.0, (s, sale) => s + sale.totalAmount);
    final totalProfit = approvedSales.fold(0.0, (s, sale) => s + sale.profit);

    String filterLabel;
    if (_showAll) {
      filterLabel = 'All Sales';
    } else if (_safeStart == _safeEnd) {
      final d = _safeStart;
      final today = _today();
      if (d == today) {
        filterLabel = "Today's Sales";
      } else if (d == today.subtract(const Duration(days: 1))) {
        filterLabel = "Yesterday's Sales";
      } else {
        filterLabel = DateFormat('MMM d, yyyy').format(d);
      }
    } else {
      filterLabel =
          '${DateFormat('MMM d').format(_safeStart)} — ${DateFormat('MMM d, yyyy').format(_safeEnd)}';
    }

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
                    Text(
                      'Sales',
                      style: TextStyle(
                        fontSize: AppTheme.fontSize(context, 20),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Revenue: ${Currency.formatWhole(totalRev)} • Profit: ${Currency.formatWhole(totalProfit)}',
                      style: TextStyle(
                        fontSize: AppTheme.fontSize(context, 13),
                        color: AppTheme.secondaryText(context),
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _showRecordSale(),
                icon: const Icon(Icons.add, size: 18),
                label: Text(
                  'Record Sale',
                  style: TextStyle(fontSize: AppTheme.fontSize(context, 14)),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.success,
                ),
              ),
            ],
          ),
        ),

        Padding(
          padding: EdgeInsets.fromLTRB(
            AppTheme.pad(context, 16),
            0,
            AppTheme.pad(context, 16),
            4,
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterBtn(
                  label: 'Today',
                  icon: Icons.today,
                  isActive:
                      !_showAll &&
                      _safeStart == _safeEnd &&
                      _safeStart == _today(),
                  onTap: _showToday,
                ),
                const SizedBox(width: 6),
                _filterBtn(
                  label: 'All',
                  icon: Icons.all_inclusive,
                  isActive: _showAll,
                  onTap: _showAllSales,
                ),
                const SizedBox(width: 6),
                _dateChip(
                  label: _formatDateLabel(_safeStart),
                  icon: Icons.calendar_today,
                  onTap: () => _pickDate(isStart: true),
                ),
                const SizedBox(width: 4),
                Text(
                  '—',
                  style: TextStyle(
                    color: AppTheme.secondaryText(context),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 4),
                _dateChip(
                  label: _formatDateLabel(_safeEnd),
                  icon: Icons.calendar_month,
                  onTap: () => _pickDate(isStart: false),
                ),
              ],
            ),
          ),
        ),

        Padding(
          padding: EdgeInsets.fromLTRB(
            AppTheme.pad(context, 16),
            4,
            AppTheme.pad(context, 16),
            8,
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              filterLabel,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.secondaryText(context),
              ),
            ),
          ),
        ),

        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _visibleSales.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.shopping_cart_outlined,
                        size: 48,
                        color: AppTheme.secondaryText(
                          context,
                        ).withValues(alpha: 0.4),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _searchQuery.isEmpty
                            ? 'No sales for this date'
                            : 'No sales match your search',
                        style: TextStyle(
                          color: AppTheme.secondaryText(context),
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(onRefresh: _load, child: _salesTable()),
        ),
      ],
    );
  }

  /// Compact table view for wide screens.
  List<Sale> get _visibleSales => _sales
      .where(
        (sale) => matchesSectionSearch(_searchQuery, [
          sale.productName,
          sale.customerName,
          sale.recordedByName,
          sale.paymentMethod,
          sale.status,
          sale.quantity,
          sale.totalAmount,
        ]),
      )
      .toList();

  Widget _salesTable() {
    final user = context.watch<AuthProvider>().user;
    final canApprove =
        user != null &&
        (user.isAdmin ||
            user.isDeveloper ||
            user.hasPermission('approve_sales'));
    final rows = <CompactDataRow>[];
    final sales = _visibleSales;
    for (var i = 0; i < sales.length; i++) {
      final s = sales[i];
      rows.add(
        CompactDataRow([
          CompactDataTable.cell(
            context,
            DateFormat('d MMM yyyy').format(s.saleDate.toLocal()),
          ),
          CompactDataTable.accent(context, s.productName ?? 'Unknown'),
          CompactDataTable.cell(
            context,
            '${s.quantity} ${s.saleUnit == 'box' ? 'box' : 'pc'}',
          ),
          CompactDataTable.cell(context, Currency.format(s.unitPrice)),
          CompactDataTable.cell(
            context,
            Currency.formatWhole(s.totalAmount),
            weight: FontWeight.w600,
          ),
          CompactDataTable.cell(
            context,
            Currency.formatWhole(s.profit),
            color: AppTheme.successBright(context),
          ),
          CompactDataTable.muted(context, s.customerName ?? 'Walk-in'),
          CompactDataTable.muted(context, s.recordedByName ?? '—'),
          CompactDataTable.chip(
            context,
            s.status == 'pending' ? 'Pending' : 'Approved',
            s.status == 'pending'
                ? AppTheme.warningBright(context)
                : AppTheme.successBright(context),
          ),
          canApprove && s.status == 'pending'
              ? CompactDataTable.actionIcon(
                  icon: Icons.check_circle_outline,
                  color: AppTheme.successBright(context),
                  tooltip: 'Approve sale',
                  onTap: () => _approveSale(s),
                )
              : const SizedBox.shrink(),
        ]),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: CompactDataTable(
        columns: const [
          CompactTableColumn('Date', flex: 2),
          CompactTableColumn('Item Name', flex: 3),
          CompactTableColumn('Qty', flex: 1),
          CompactTableColumn('Unit Price', flex: 2),
          CompactTableColumn('Total', flex: 2),
          CompactTableColumn('Profit', flex: 2),
          CompactTableColumn('Customer', flex: 2),
          CompactTableColumn('Recorded By', flex: 2),
          CompactTableColumn('Status', flex: 2),
          CompactTableColumn('Actions', flex: 2, rightAligned: true),
        ],
        rows: rows,
      ),
    );
  }

  Future<void> _approveSale(Sale sale) async {
    try {
      await ApiService.approveSale(sale.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sale approved.'),
          backgroundColor: AppTheme.success,
        ),
      );
      AppEvents.instance.emit('sales');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          backgroundColor: AppTheme.danger,
        ),
      );
    }
  }

  Widget _filterBtn({
    required String label,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return PeriodFilterChip(label: label, selected: isActive, onTap: onTap);
  }

  Widget _dateChip({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return PeriodFilterChip(
      label: label,
      selected: false,
      onTap: onTap,
      icon: icon,
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
                SearchablePicker<Product>(
                  label: 'Product',
                  selected: selectedProduct,
                  items: _products,
                  itemLabel: (p) {
                    final stockInfo = p.sellsAsBox
                        ? '${p.stockBoxes} bx, ${p.currentStock} pc'
                        : '${p.currentStock} pc';
                    return '${p.name} ($stockInfo)';
                  },
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
                    value:
                        (selectedProduct != null &&
                            !selectedProduct!.sellsAsBox)
                        ? 'piece'
                        : saleUnit,
                    items: const [
                      DropdownMenuItem(
                        value: 'piece',
                        child: Text('Individual Pieces'),
                      ),
                      DropdownMenuItem(value: 'box', child: Text('Full Box')),
                    ],
                    onChanged: (v) {
                      setDialogState(() {
                        saleUnit = v ?? 'piece';
                        if (selectedProduct != null) {
                          if (saleUnit == 'box') {
                            priceCtrl.text =
                                selectedProduct!.boxSellingPrice?.toString() ??
                                (selectedProduct!.sellingPrice *
                                        selectedProduct!.unitsPerBox)
                                    .toString();
                          } else {
                            priceCtrl.text = selectedProduct!.sellingPrice
                                .toString();
                          }
                        }
                      });
                    },
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: qtyCtrl,
                  decoration: const InputDecoration(labelText: 'Quantity'),
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setDialogState(() {}),
                ),
                if (saleUnit == 'piece' &&
                    selectedProduct != null &&
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
                      border: Border.all(
                        color: AppTheme.warning.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber,
                          size: 16,
                          color: AppTheme.warning,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'No loose pieces available. A box will be opened (${selectedProduct!.unitsPerBox} pc/box).',
                            style: TextStyle(
                              fontSize: AppTheme.fontSize(context, 12),
                              color: AppTheme.warning,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: priceCtrl,
                  decoration: const InputDecoration(labelText: 'Unit Price'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: customerCtrl,
                  decoration: const InputDecoration(labelText: 'Customer Name'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            LoadingElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.success,
              ),
              loadingChild: const Text('Recording...'),
              onPressed: () async {
                if (selectedProduct == null || qtyCtrl.text.isEmpty) return;
                try {
                  await ApiService.createSale({
                    'productId': selectedProduct!.id,
                    'quantity': int.tryParse(qtyCtrl.text) ?? 0,
                    'unitPrice':
                        double.tryParse(priceCtrl.text) ??
                        selectedProduct!.sellingPrice,
                    'saleUnit': saleUnit,
                    'customerName': customerCtrl.text.isNotEmpty
                        ? customerCtrl.text
                        : null,
                  });
                  if (ctx.mounted) Navigator.pop(ctx);

                  AppEvents.instance.emit('products');
                  AppEvents.instance.emit('sales');
                  _showToday();
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                        content: Text(e.toString()),
                        backgroundColor: AppTheme.danger,
                      ),
                    );
                  }
                }
              },
              child: const Text('Record'),
            ),
          ],
        ),
      ),
    );
  }
}
