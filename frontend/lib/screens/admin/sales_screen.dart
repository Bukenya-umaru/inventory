import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../services/app_events.dart';
import '../../models/sale.dart';
import '../../models/product.dart';
import '../../widgets/compact_data_table.dart';
import '../../utils/theme.dart';
import '../../utils/currency.dart';

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
    if (event == 'products') {
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

        final startUtc = DateTime(_safeStart.year, _safeStart.month, _safeStart.day).toUtc();
        final endUtc = DateTime(_safeEnd.year, _safeEnd.month, _safeEnd.day, 23, 59, 59, 999).toUtc();
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
        _sales = (salesRes['sales'] as List).map((s) => Sale.fromJson(s)).toList();
        _products = (prodRes['products'] as List).map((p) => Product.fromJson(p)).toList();
        _loading = false;
      });
    } catch (e) { setState(() => _loading = false); }
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
    setState(() { _showAll = true; });
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
    final totalRev = _sales.fold(0.0, (s, sale) => s + sale.totalAmount);
    final totalProfit = _sales.fold(0.0, (s, sale) => s + sale.profit);

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
      filterLabel = '${DateFormat('MMM d').format(_safeStart)} — ${DateFormat('MMM d, yyyy').format(_safeEnd)}';
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
                        Text('Sales', style: TextStyle(fontSize: AppTheme.fontSize(context, 20), fontWeight: FontWeight.bold)),
                        Text('Revenue: ${Currency.formatWhole(totalRev)} • Profit: ${Currency.formatWhole(totalProfit)}',
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

        Padding(
          padding: EdgeInsets.fromLTRB(
            AppTheme.pad(context, 16), 0,
            AppTheme.pad(context, 16), 4,
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterBtn(
                  label: 'Today',
                  icon: Icons.today,
                  isActive: !_showAll && _safeStart == _safeEnd && _safeStart == _today(),
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
                Text('—', style: TextStyle(color: AppTheme.secondaryText(context), fontSize: 14)),
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
          padding: EdgeInsets.fromLTRB(AppTheme.pad(context, 16), 4, AppTheme.pad(context, 16), 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(filterLabel,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.secondaryText(context))),
          ),
        ),

        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _sales.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.shopping_cart_outlined, size: 48,
                            color: AppTheme.secondaryText(context).withValues(alpha: 0.4)),
                          const SizedBox(height: 12),
                          Text('No sales for this date',
                            style: TextStyle(color: AppTheme.secondaryText(context), fontSize: 15)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: MediaQuery.of(context).size.width >= 900
                          ? _salesTable()
                          : _buildGroupedList(),
                    ),
        ),
      ],
    );
  }

  /// Compact table view for wide screens.
  Widget _salesTable() {
    final rows = <CompactDataRow>[];
    for (var i = 0; i < _sales.length; i++) {
      final s = _sales[i];
      rows.add(CompactDataRow([
        CompactDataTable.cell(context, DateFormat('d MMM yyyy').format(s.saleDate.toLocal())),
        CompactDataTable.accent(context, s.productName ?? 'Unknown'),
        CompactDataTable.cell(context, '${s.quantity} ${s.saleUnit == 'box' ? 'box' : 'pc'}'),
        CompactDataTable.cell(context, Currency.format(s.unitPrice)),
        CompactDataTable.cell(context, Currency.formatWhole(s.totalAmount), weight: FontWeight.w600),
        CompactDataTable.cell(context, Currency.formatWhole(s.profit),
            color: AppTheme.successBright(context)),
        CompactDataTable.muted(context, s.customerName ?? 'Walk-in'),
        CompactDataTable.muted(context, s.recordedByName ?? '—'),
      ]));
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
        ],
        rows: rows,
      ),
    );
  }

  Widget _buildGroupedList() {
    final Map<String, List<Sale>> grouped = {};
    for (final sale in _sales) {
      final dateKey = DateFormat('yyyy-MM-dd').format(sale.saleDate.toLocal());
      grouped.putIfAbsent(dateKey, () => []).add(sale);
    }
    final sortedDates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    final List<Widget> items = [];
    for (final dateKey in sortedDates) {
      final daySales = grouped[dateKey]!;
      final dayRevenue = daySales.fold(0.0, (s, sale) => s + sale.totalAmount);
      final dayProfit = daySales.fold(0.0, (s, sale) => s + sale.profit);
      final date = DateTime.parse(dateKey);

      if (sortedDates.length > 1) {
        items.add(_dateHeader(date, daySales.length, dayRevenue, dayProfit));
      }
      for (final s in daySales) {
        items.add(_saleCard(s));
      }
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        AppTheme.pad(context, 16), 0,
        AppTheme.pad(context, 16), 80),
      itemCount: items.length,
      itemBuilder: (ctx, i) => items[i],
    );
  }

  Widget _dateHeader(DateTime date, int count, double revenue, double profit) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final saleDay = DateTime(date.year, date.month, date.day);
    String label;
    if (saleDay == today) {
      label = 'Today';
    } else if (saleDay == today.subtract(const Duration(days: 1))) {
      label = 'Yesterday';
    } else {
      label = DateFormat('EEEE, MMM d, yyyy').format(date);
    }

    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.calendar_today, size: 16, color: AppTheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.textColor(context))),
                Text('$count sale${count != 1 ? 's' : ''}',
                  style: TextStyle(fontSize: 11, color: AppTheme.secondaryText(context))),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(Currency.formatWhole(revenue),
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primary)),
              Text('Profit: ${Currency.formatWhole(profit)}',
                style: TextStyle(fontSize: 11, color: AppTheme.success)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _saleCard(Sale s) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        title: Text(s.productName ?? 'Unknown', maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: AppTheme.fontSize(context, 14))),
        subtitle: Text(
          'Qty: ${s.quantity} ${s.saleUnit == 'box' ? 'box' : 'pc'} • ${Currency.format(s.unitPrice)} each'
          '${s.customerName != null ? ' • ${s.customerName}' : ''}',
          maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: AppTheme.fontSize(context, 12))),
        leading: Icon(Icons.shopping_cart, size: 20, color: AppTheme.success),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(Currency.formatWhole(s.totalAmount), maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: AppTheme.fontSize(context, 13))),
            Text('Profit: ${Currency.formatWhole(s.profit)}', maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: AppTheme.fontSize(context, 11), color: AppTheme.success)),
          ],
        ),
      ),
    );
  }

  Widget _filterBtn({required String label, required IconData icon, required bool isActive, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: isActive
              ? AppTheme.primary
              : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? AppTheme.primary : Theme.of(context).dividerColor.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isActive ? Colors.white : AppTheme.secondaryText(context)),
            const SizedBox(width: 4),
            Text(label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: isActive ? Colors.white : AppTheme.secondaryText(context),
              )),
          ],
        ),
      ),
    );
  }

  Widget _dateChip({required String label, required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppTheme.secondaryText(context)),
            const SizedBox(width: 4),
            Text(label,
              style: TextStyle(fontSize: 12, color: AppTheme.secondaryText(context))),
          ],
        ),
      ),
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
                try {
                  await ApiService.createSale({
                    'productId': selectedProduct!.id,
                    'quantity': int.tryParse(qtyCtrl.text) ?? 0,
                    'unitPrice': double.tryParse(priceCtrl.text) ?? selectedProduct!.sellingPrice,
                    'saleUnit': saleUnit,
                    'customerName': customerCtrl.text.isNotEmpty ? customerCtrl.text : null,
                  });
                  if (ctx.mounted) Navigator.pop(ctx);

                  AppEvents.instance.emit('products');
                  AppEvents.instance.emit('sales');
                  _showToday();
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.danger),
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