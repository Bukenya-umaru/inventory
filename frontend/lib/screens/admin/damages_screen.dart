import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../services/app_events.dart';
import '../../models/damage.dart';
import '../../models/product.dart';
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

        final startUtc = DateTime(_safeStart.year, _safeStart.month, _safeStart.day).toUtc();
        final endUtc = DateTime(_safeEnd.year, _safeEnd.month, _safeEnd.day, 23, 59, 59, 999).toUtc();
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
        _damages = (dmgRes['damages'] as List).map((d) => Damage.fromJson(d)).toList();
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

  void _showAllDamages() {
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
                    Text('Damage Reports', style: TextStyle(fontSize: AppTheme.fontSize(context, 20), fontWeight: FontWeight.bold)),
                    Text('Total loss: ${Currency.formatWhole(totalLoss)}', style: TextStyle(fontSize: AppTheme.fontSize(context, 13), color: AppTheme.secondaryText(context))),
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
                  onTap: _showAllDamages,
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
              : _damages.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.warning_amber_outlined, size: 48,
                            color: AppTheme.secondaryText(context).withValues(alpha: 0.4)),
                          const SizedBox(height: 12),
                          Text('No damages for this date',
                            style: TextStyle(color: AppTheme.secondaryText(context), fontSize: 15)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: _buildGroupedList(),
                    ),
        ),
      ],
    );
  }

  Widget _buildGroupedList() {
    final Map<String, List<Damage>> grouped = {};
    for (final damage in _damages) {
      final dateKey = DateFormat('yyyy-MM-dd').format(damage.reportDate.toLocal());
      grouped.putIfAbsent(dateKey, () => []).add(damage);
    }
    final sortedDates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    final List<Widget> items = [];
    for (final dateKey in sortedDates) {
      final dayDamages = grouped[dateKey]!;
      final dayLoss = dayDamages.fold(0.0, (s, d) => s + d.estimatedLoss);
      final date = DateTime.parse(dateKey);

      if (sortedDates.length > 1) {
        items.add(_dateHeader(date, dayDamages.length, dayLoss));
      }
      for (final d in dayDamages) {
        items.add(_damageCard(d));
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

  Widget _dateHeader(DateTime date, int count, double loss) {
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
          Icon(Icons.calendar_today, size: 16, color: AppTheme.danger),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.textColor(context))),
                Text('$count damage${count != 1 ? 's' : ''}',
                  style: TextStyle(fontSize: 11, color: AppTheme.secondaryText(context))),
              ],
            ),
          ),
          Text('Loss: -${Currency.formatWhole(loss)}',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.danger)),
        ],
      ),
    );
  }

  Widget _damageCard(Damage d) {
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
            Text('-${Currency.formatWhole(d.estimatedLoss)}', maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: AppTheme.fontSize(context, 12), color: AppTheme.danger)),
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
                      SnackBar(content: Text(e.toString()), backgroundColor: AppTheme.danger),
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