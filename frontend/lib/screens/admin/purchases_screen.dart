import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../models/purchase.dart';
import '../../utils/theme.dart';
import '../../utils/currency.dart';

class PurchasesScreen extends StatefulWidget {
  const PurchasesScreen({super.key});
  @override
  State<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends State<PurchasesScreen> {
  List<Purchase> _purchases = [];
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
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      String? startStr;
      String? endStr;
      if (!_showAll) {
        final startUtc =
            DateTime(_safeStart.year, _safeStart.month, _safeStart.day).toUtc();
        final endUtc = DateTime(
                _safeEnd.year, _safeEnd.month, _safeEnd.day, 23, 59, 59, 999)
            .toUtc();
        startStr = startUtc.toIso8601String();
        endStr = endUtc.toIso8601String();
      }
      final purchRes = await ApiService.getPurchases(startDate: startStr, endDate: endStr);
      setState(() {
        _purchases = (purchRes['purchases'] as List)
            .map((p) => Purchase.fromJson(p))
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

  void _showAllPurchases() {
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
    final totalCost = _purchases.fold(0.0, (s, p) => s + p.totalCost);

    String filterLabel;
    if (_showAll) {
      filterLabel = 'All Purchases';
    } else if (_safeStart == _safeEnd) {
      final d = _safeStart;
      final today = _today();
      if (d == today) {
        filterLabel = "Today's Purchases";
      } else if (d == today.subtract(const Duration(days: 1))) {
        filterLabel = "Yesterday's Purchases";
      } else {
        filterLabel = DateFormat('MMM d, yyyy').format(d);
      }
    } else {
      filterLabel =
          '${DateFormat('MMM d').format(_safeStart)} — ${DateFormat('MMM d, yyyy').format(_safeEnd)}';
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 800;
        final content = Column(
          children: [
            // ── Header ──
            Padding(
              padding: EdgeInsets.all(AppTheme.pad(context, 16)),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Purchases',
                            style: TextStyle(
                                fontSize: AppTheme.fontSize(context, 20),
                                fontWeight: FontWeight.bold)),
                        Text(
                            'Total Cost: ${Currency.formatWhole(totalCost)} • ${_purchases.length} records',
                            style: TextStyle(
                                fontSize: AppTheme.fontSize(context, 13),
                                color: AppTheme.secondaryText(context))),
                      ],
                    ),
                  ),
                ],
              ),
            ),

        // ── Filter Bar ──
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
                  isActive: !_showAll &&
                      _safeStart == _safeEnd &&
                      _safeStart == _today(),
                  onTap: _showToday,
                ),
                const SizedBox(width: 6),
                _filterBtn(
                  label: 'All',
                  icon: Icons.all_inclusive,
                  isActive: _showAll,
                  onTap: _showAllPurchases,
                ),
                const SizedBox(width: 6),
                _dateChip(
                  label: _formatDateLabel(_safeStart),
                  icon: Icons.calendar_today,
                  onTap: () => _pickDate(isStart: true),
                ),
                const SizedBox(width: 4),
                Text('—',
                    style: TextStyle(
                        color: AppTheme.secondaryText(context), fontSize: 14)),
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

        // ── Active filter label ──
        Padding(
          padding: EdgeInsets.fromLTRB(
              AppTheme.pad(context, 16), 4, AppTheme.pad(context, 16), 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(filterLabel,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.secondaryText(context))),
          ),
        ),

        // ── Purchases List ──
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _purchases.isEmpty
                  ? _emptyState()
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: _buildGroupedList(),
                    ),
        ),
      ],
        );
        if (isWide) {
          return Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 720), child: content));
        }
        return content;
      },
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
            child: Icon(Icons.local_shipping_outlined,
                size: 56,
                color: AppTheme.primary.withValues(alpha: 0.4)),
          ),
          const SizedBox(height: 16),
          Text('No purchases found',
              style: TextStyle(
                  fontSize: AppTheme.fontSize(context, 18),
                  fontWeight: FontWeight.w600,
                  color: AppTheme.secondaryText(context))),
          const SizedBox(height: 6),
          Text('Add stock to products from the Products section',
              style: TextStyle(
                  fontSize: AppTheme.fontSize(context, 13),
                  color: AppTheme.secondaryText(context))),
        ],
      ),
    );
  }

  Widget _buildGroupedList() {
    final Map<String, List<Purchase>> grouped = {};
    for (final purchase in _purchases) {
      final dateKey =
          DateFormat('yyyy-MM-dd').format(purchase.purchaseDate.toLocal());
      grouped.putIfAbsent(dateKey, () => []).add(purchase);
    }
    final sortedDates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    final List<Widget> items = [];
    for (final dateKey in sortedDates) {
      final dayPurchases = grouped[dateKey]!;
      final dayCost = dayPurchases.fold(0.0, (s, p) => s + p.totalCost);
      final date = DateTime.parse(dateKey);

      if (sortedDates.length > 1) {
        items.add(_dateHeader(date, dayPurchases.length, dayCost));
      }
      for (final p in dayPurchases) {
        items.add(_purchaseCard(p));
      }
    }

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(
          AppTheme.pad(context, 16), 0, AppTheme.pad(context, 16), 80),
      itemCount: items.length,
      itemBuilder: (ctx, i) => items[i],
    );
  }

  Widget _dateHeader(DateTime date, int count, double cost) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final purchaseDay = DateTime(date.year, date.month, date.day);
    String label;
    if (purchaseDay == today) {
      label = 'Today';
    } else if (purchaseDay == today.subtract(const Duration(days: 1))) {
      label = 'Yesterday';
    } else {
      label = DateFormat('EEEE, MMM d, yyyy').format(date);
    }

    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.5),
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
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: AppTheme.textColor(context))),
                Text('$count purchase${count != 1 ? 's' : ''}',
                    style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.secondaryText(context))),
              ],
            ),
          ),
          Text(Currency.formatWhole(cost),
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: AppTheme.primary)),
        ],
      ),
    );
  }

  Widget _purchaseCard(Purchase p) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        title: Text(p.productName ?? 'Unknown',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: AppTheme.fontSize(context, 14))),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Qty: ${p.quantity} ${p.purchaseUnit == 'box' ? 'box' : 'pc'} • ${Currency.format(p.unitCost)} each',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: AppTheme.fontSize(context, 12)),
            ),
            if (p.supplier != null && p.supplier!.isNotEmpty)
              Text(
                'Supplier: ${p.supplier!}${p.supplierPhone != null && p.supplierPhone!.isNotEmpty ? ' • ${p.supplierPhone}' : ''}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: AppTheme.fontSize(context, 11),
                    color: AppTheme.secondaryText(context)),
              ),
            if (p.invoiceNumber != null && p.invoiceNumber!.isNotEmpty)
              Text(
                'INV: ${p.invoiceNumber} • ${_paymentLabel(p.paymentMethod)}',
                style: TextStyle(
                    fontSize: AppTheme.fontSize(context, 11),
                    color: AppTheme.secondaryText(context)),
              ),
          ],
        ),
        leading:
            Icon(Icons.local_shipping, size: 20, color: AppTheme.primary),
        trailing: Text(Currency.formatWhole(p.totalCost),
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: AppTheme.fontSize(context, 13))),
      ),
    );
  }

  String _paymentLabel(String? method) {
    switch (method) {
      case 'cash':
        return 'Cash';
      case 'credit':
        return 'Credit';
      case 'bank_transfer':
        return 'Bank Transfer';
      case 'mobile_money':
        return 'Mobile Money';
      case 'other':
        return 'Other';
      default:
        return 'Cash';
    }
  }

  Widget _filterBtn(
      {required String label,
      required IconData icon,
      required bool isActive,
      required VoidCallback onTap}) {
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
            Icon(icon,
                size: 14,
                color: isActive
                    ? Colors.white
                    : AppTheme.secondaryText(context)),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  color: isActive
                      ? Colors.white
                      : AppTheme.secondaryText(context),
                )),
          ],
        ),
      ),
    );
  }

  Widget _dateChip(
      {required String label,
      required IconData icon,
      required VoidCallback onTap}) {
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
                style: TextStyle(
                    fontSize: 12, color: AppTheme.secondaryText(context))),
          ],
        ),
      ),
    );
  }
}
