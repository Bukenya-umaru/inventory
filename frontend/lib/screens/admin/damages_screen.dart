import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../services/app_events.dart';
import '../../models/damage.dart';
import '../../models/product.dart';
import '../../widgets/compact_data_table.dart';
import '../../widgets/loading_button.dart';
import '../../widgets/searchable_picker.dart';
import '../../widgets/section_search_bar.dart';
import '../../utils/theme.dart';
import '../../utils/currency.dart';

class DamagesScreen extends StatefulWidget {
  const DamagesScreen({super.key});
  @override
  State<DamagesScreen> createState() => _DamagesScreenState();
}

class _DamagesScreenState extends State<DamagesScreen> {
  List<Damage> _damages = [];
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
    } else if (event == 'damages') {
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
        ApiService.getDamages(startDate: startStr, endDate: endStr),
        ApiService.getProducts(),
      ]);
      final dmgRes = results[0];
      final prodRes = results[1];
      setState(() {
        _damages = (dmgRes['damages'] as List)
            .map((d) => Damage.fromJson(d))
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

  void _showAllDamages() {
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
    final totalLoss = _damages.fold(0.0, (s, d) => s + d.estimatedLoss);

    String filterLabel;
    if (_showAll) {
      filterLabel = 'All Damages';
    } else if (_safeStart == _safeEnd) {
      final d = _safeStart;
      final today = _today();
      if (d == today) {
        filterLabel = "Today's Damages";
      } else if (d == today.subtract(const Duration(days: 1))) {
        filterLabel = "Yesterday's Damages";
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
                      'Damage Reports',
                      style: TextStyle(
                        fontSize: AppTheme.fontSize(context, 20),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Total loss: ${Currency.formatWhole(totalLoss)}',
                      style: TextStyle(
                        fontSize: AppTheme.fontSize(context, 13),
                        color: AppTheme.secondaryText(context),
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _showReport(),
                icon: const Icon(Icons.add, size: 18),
                label: Text(
                  'Report',
                  style: TextStyle(fontSize: AppTheme.fontSize(context, 14)),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.danger,
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
                  onTap: _showAllDamages,
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
              : _visibleDamages.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.warning_amber_outlined,
                        size: 48,
                        color: AppTheme.secondaryText(
                          context,
                        ).withValues(alpha: 0.4),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _searchQuery.isEmpty
                            ? 'No damages for this date'
                            : 'No damage reports match your search',
                        style: TextStyle(
                          color: AppTheme.secondaryText(context),
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(onRefresh: _load, child: _damagesTable()),
        ),
      ],
    );
  }

  /// Compact table view for wide screens.
  List<Damage> get _visibleDamages => _damages
      .where((damage) => matchesSectionSearch(_searchQuery, [
            damage.productName,
            damage.reason,
            damage.reportedByName,
            damage.quantity,
          ]))
      .toList();

  Widget _damagesTable() {
    final rows = <CompactDataRow>[];
    for (final d in _visibleDamages) {
      rows.add(
        CompactDataRow([
          CompactDataTable.cell(
            context,
            DateFormat('d MMM yyyy').format(d.reportDate.toLocal()),
          ),
          CompactDataTable.accent(context, d.productName ?? 'Unknown'),
          CompactDataTable.cell(
            context,
            '${d.quantity} ${d.damageUnit == 'box' ? 'box' : 'pc'}',
          ),
          CompactDataTable.muted(context, d.reason),
          CompactDataTable.cell(
            context,
            '-${Currency.formatWhole(d.estimatedLoss)}',
            color: AppTheme.dangerBright(context),
            weight: FontWeight.w600,
          ),
          CompactDataTable.muted(context, d.reportedByName ?? '—'),
        ]),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: CompactDataTable(
        columns: const [
          CompactTableColumn('Date', flex: 2),
          CompactTableColumn('Product', flex: 3),
          CompactTableColumn('Qty', flex: 1),
          CompactTableColumn('Reason', flex: 3),
          CompactTableColumn('Est. Loss', flex: 2),
          CompactTableColumn('Reported By', flex: 2),
        ],
        rows: rows,
      ),
    );
  }

  Widget _filterBtn({
    required String label,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.primary : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive
                ? AppTheme.primary
                : Theme.of(context).dividerColor.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isActive ? Colors.white : AppTheme.secondaryText(context),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: isActive
                    ? Colors.white
                    : AppTheme.secondaryText(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateChip({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
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
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.secondaryText(context),
              ),
            ),
          ],
        ),
      ),
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
                      if (v != null) damageUnit = 'piece';
                    });
                  },
                ),
                if (selectedProduct == null || selectedProduct!.sellsAsBox) ...[
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Damage Unit'),
                    value:
                        (selectedProduct != null &&
                            !selectedProduct!.sellsAsBox)
                        ? 'piece'
                        : damageUnit,
                    items: const [
                      DropdownMenuItem(
                        value: 'piece',
                        child: Text('Individual Pieces'),
                      ),
                      DropdownMenuItem(value: 'box', child: Text('Full Box')),
                    ],
                    onChanged: (v) =>
                        setDialogState(() => damageUnit = v ?? 'piece'),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: qtyCtrl,
                  decoration: const InputDecoration(labelText: 'Quantity'),
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setDialogState(() {}),
                ),
                if (damageUnit == 'piece' &&
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
                            'No loose pieces. A box will be opened (${selectedProduct!.unitsPerBox} pc/box).',
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
                  controller: reasonCtrl,
                  decoration: const InputDecoration(labelText: 'Reason'),
                  maxLines: 3,
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
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
              loadingChild: const Text('Reporting...'),
              onPressed: () async {
                if (selectedProduct == null ||
                    qtyCtrl.text.isEmpty ||
                    reasonCtrl.text.isEmpty)
                  return;
                try {
                  await ApiService.createDamage({
                    'productId': selectedProduct!.id,
                    'quantity': int.tryParse(qtyCtrl.text) ?? 0,
                    'damageUnit': damageUnit,
                    'reason': reasonCtrl.text,
                  });
                  if (ctx.mounted) Navigator.pop(ctx);

                  AppEvents.instance.emit('products');
                  AppEvents.instance.emit('damages');
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
              child: const Text('Report'),
            ),
          ],
        ),
      ),
    );
  }
}
