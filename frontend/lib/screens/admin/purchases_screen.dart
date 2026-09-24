import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../services/app_events.dart';
import '../../services/auth_provider.dart';
import '../../models/purchase.dart';
import '../../models/supplier.dart';
import '../../widgets/supplier_picker.dart';
import '../../widgets/compact_data_table.dart';
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
  bool _showPendingOnly = false;

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
    if (event == 'purchases') {
      _load();
    }
  }

  @override
  void dispose() {
    AppEvents.instance.unsubscribe(_onEvent);
    super.dispose();
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
                        Text('Stock History',
                            style: TextStyle(
                                fontSize: AppTheme.fontSize(context, 20),
                                fontWeight: FontWeight.bold)),
                        Text(
                            '$_pendingCount pending • Total Cost: ${Currency.formatWhole(totalCost)} • ${_purchases.length} records',
                            style: TextStyle(
                                fontSize: AppTheme.fontSize(context, 13),
                                color: AppTheme.secondaryText(context))),
                      ],
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
                  label: 'Pending${_pendingCount > 0 ? ' ($_pendingCount)' : ''}',
                  icon: Icons.hourglass_top,
                  isActive: _showPendingOnly,
                  onTap: () => setState(() => _showPendingOnly = !_showPendingOnly),
                ),
                const SizedBox(width: 6),
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

        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _filteredPurchases().isEmpty
                  ? _emptyState()
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: MediaQuery.of(context).size.width >= 900
                          ? _purchasesTable()
                          : _buildGroupedList(),
                    ),
        ),
      ],
    );
  }

  List<Purchase> _filteredPurchases() {
    if (!_showPendingOnly) return _purchases;
    return _purchases.where((p) => p.isPending).toList();
  }

  int get _pendingCount => _purchases.where((p) => p.isPending).length;

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
          Text('Add stock to products from the Stock section',
              style: TextStyle(
                  fontSize: AppTheme.fontSize(context, 13),
                  color: AppTheme.secondaryText(context))),
        ],
      ),
    );
  }

  /// Compact table view for wide screens.
  Widget _purchasesTable() {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final canApprove = user != null &&
        (user.isAdmin || user.isDeveloper || user.hasPermission('record_purchases'));
    final canEdit = user != null &&
        (user.isAdmin || user.isDeveloper || user.hasPermission('create_products'));

    final purchases = _filteredPurchases();
    final rows = <CompactDataRow>[];
    for (var i = 0; i < purchases.length; i++) {
      final p = purchases[i];
      final actions = <Widget>[
        if (canEdit && p.isPending)
          CompactDataTable.actionIcon(
            icon: Icons.edit_outlined,
            color: AppTheme.blueBright(context),
            tooltip: 'Edit before approval',
            onTap: () => _showEditDialog(p),
          ),
        if (canApprove && p.isPending)
          CompactDataTable.actionIcon(
            icon: Icons.check_circle_outline,
            color: AppTheme.successBright(context),
            tooltip: 'Approve & apply stock',
            onTap: () => _approvePurchase(p),
          ),
      ];

      rows.add(CompactDataRow([
        CompactDataTable.cell(context, DateFormat('d MMM yyyy').format(p.purchaseDate.toLocal())),
        CompactDataTable.accent(context, p.productName ?? 'Unknown'),
        CompactDataTable.cell(context, '${p.quantity} ${p.purchaseUnit == 'box' ? 'box' : 'pc'}'),
        CompactDataTable.cell(context, Currency.format(p.unitCost)),
        CompactDataTable.cell(context, Currency.formatWhole(p.totalCost), weight: FontWeight.w600),
        CompactDataTable.muted(context,
            (p.supplier != null && p.supplier!.isNotEmpty) ? p.supplier! : '—'),
        CompactDataTable.muted(context,
            (p.invoiceNumber != null && p.invoiceNumber!.isNotEmpty) ? 'INV: ${p.invoiceNumber}' : '—'),
        CompactDataTable.chip(
          context,
          p.isPending ? 'Pending' : 'Approved',
          p.isPending ? AppTheme.warningBright(context) : AppTheme.successBright(context),
        ),
        CompactDataTable.actions(actions),
      ]));
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: CompactDataTable(
        columns: const [
          CompactTableColumn('Date', flex: 2),
          CompactTableColumn('Product', flex: 3),
          CompactTableColumn('Qty', flex: 1),
          CompactTableColumn('Unit Cost', flex: 2),
          CompactTableColumn('Total', flex: 2),
          CompactTableColumn('Supplier', flex: 2),
          CompactTableColumn('Invoice', flex: 2),
          CompactTableColumn('Status', flex: 2),
          CompactTableColumn('Actions', flex: 2, rightAligned: true),
        ],
        rows: rows,
      ),
    );
  }

  Widget _buildGroupedList() {
    final purchases = _filteredPurchases();
    final Map<String, List<Purchase>> grouped = {};
    for (final purchase in purchases) {
      final dateKey =
          DateFormat('yyyy-MM-dd').format(purchase.purchaseDate.toLocal());
      grouped.putIfAbsent(dateKey, () => []).add(purchase);
    }
    final sortedDates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    final List<Widget> items = [];
    for (final dateKey in sortedDates) {
      final dayPurchases = grouped[dateKey]!;
      final dayCost =
          dayPurchases.where((p) => p.isApproved).fold(0.0, (s, p) => s + p.totalCost);
      final date = DateTime.parse(dateKey);

      if (sortedDates.length > 1) {
        items.add(_dateHeader(date, dayPurchases.length, dayCost));
      }
      for (final p in dayPurchases) {
        items.add(_purchaseCard(p));
      }
    }
    if (items.isEmpty) {
      items.add(Padding(
        padding: const EdgeInsets.only(top: 40),
        child: _emptyState(),
      ));
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
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
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final canApprove = user != null && (user.isAdmin || user.isDeveloper || user.hasPermission('record_purchases'));
    final canEdit = p.isPending &&
        user != null &&
        (user.isAdmin || user.isDeveloper || user.hasPermission('create_products'));

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      color: p.isPending ? AppTheme.warning.withValues(alpha: 0.05) : null,
      child: ListTile(
        onTap: p.editHistory.isNotEmpty ? () => _showEditHistory(p) : null,
        title: Row(
          children: [
            Expanded(
              child: Text(p.productName ?? 'Unknown',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: AppTheme.fontSize(context, 14))),
            ),
            _statusChip(p),
          ],
        ),
        subtitle: Text(
          'Qty: ${p.quantity} ${p.purchaseUnit == 'box' ? 'box' : 'pc'} • ${Currency.format(p.unitCost)} each'
          '${p.supplier != null && p.supplier!.isNotEmpty ? ' • ${p.supplier!}' : ''}'
          '${p.invoiceNumber != null && p.invoiceNumber!.isNotEmpty ? ' • INV: ${p.invoiceNumber}' : ''}'
          '${p.recordedByName != null ? ' • by ${p.recordedByName}' : ''}'
          '${p.editHistory.isNotEmpty ? ' • edited ×${p.editHistory.length}' : ''}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: AppTheme.fontSize(context, 12))),
        leading: Icon(
            p.isPending ? Icons.hourglass_top : Icons.local_shipping,
            size: 20,
            color: p.isPending ? AppTheme.warning : AppTheme.primary),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(Currency.formatWhole(p.totalCost),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: AppTheme.fontSize(context, 13))),
                Text(_paymentLabel(p.paymentMethod),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: AppTheme.fontSize(context, 11),
                        color: AppTheme.secondaryText(context))),
              ],
            ),
            if (canEdit) ...[
              const SizedBox(width: 4),
              IconButton(
                icon: Icon(Icons.edit_outlined,
                    size: 18, color: AppTheme.blueBright(context)),
                tooltip: 'Edit before approval',
                onPressed: () => _showEditDialog(p),
              ),
            ],
            if (canApprove && p.isPending) ...[
              const SizedBox(width: 4),
              IconButton(
                icon: Icon(Icons.check_circle_outline,
                    size: 18, color: AppTheme.successBright(context)),
                tooltip: 'Approve & apply stock',
                onPressed: () => _approvePurchase(p),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statusChip(Purchase p) {
    final isPending = p.isPending;
    final color = isPending ? AppTheme.warning : AppTheme.success;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isPending ? 'Pending' : 'Approved',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Future<void> _approvePurchase(Purchase p) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Approve Stock Entry'),
        content: Text(
            'Approve ${p.quantity} ${p.purchaseUnit == 'box' ? 'box(es)' : 'piece(s)'} of "${p.productName ?? 'product'}"?\n\nStock will be added to the product and the record will be locked from editing.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.success),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Approve')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final res = await ApiService.approvePurchase(p.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(res['message'] ?? 'Stock entry approved.'),
          backgroundColor: AppTheme.success));
      AppEvents.instance.emit('purchases');
      AppEvents.instance.emit('products');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString()), backgroundColor: AppTheme.danger));
    }
  }

  void _showEditDialog(Purchase p) {
    final qtyCtrl = TextEditingController(text: p.quantity.toString());
    final unitCostCtrl = TextEditingController(text: p.unitCost % 1 == 0 ? p.unitCost.toInt().toString() : p.unitCost.toString());
    Supplier? selectedSupplier =
        (p.supplierId != null && p.supplierId!.isNotEmpty)
            ? Supplier(id: p.supplierId!, name: p.supplier ?? '', phone: p.supplierPhone, email: p.supplierEmail)
            : null;
    final invoiceCtrl = TextEditingController(text: p.invoiceNumber ?? '');
    final notesCtrl = TextEditingController(text: p.notes ?? '');
    String unit = p.purchaseUnit;
    String paymentMethod = p.paymentMethod ?? 'cash';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Edit Stock Record',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              Text(
                  '${p.productName ?? 'Product'} — pending approval, changes are logged for the owner',
                  style: TextStyle(
                      fontSize: 12, color: AppTheme.secondaryText(context))),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: qtyCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Quantity *', filled: true),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Boxes'),
                        selected: unit == 'box',
                        onSelected: (_) =>
                            setDialogState(() => unit = 'box'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Pieces'),
                        selected: unit == 'piece',
                        onSelected: (_) =>
                            setDialogState(() => unit = 'piece'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: unitCostCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Unit Cost *', filled: true),
                ),
                const SizedBox(height: 12),
                SupplierPicker(
                  selected: selectedSupplier,
                  onChanged: (s) => setDialogState(() => selectedSupplier = s),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: invoiceCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Invoice Number', filled: true),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  decoration:
                      const InputDecoration(labelText: 'Payment Method'),
                  value: paymentMethod,
                  items: const [
                    DropdownMenuItem(value: 'cash', child: Text('Cash')),
                    DropdownMenuItem(value: 'credit', child: Text('Credit')),
                    DropdownMenuItem(
                        value: 'bank_transfer',
                        child: Text('Bank Transfer')),
                    DropdownMenuItem(
                        value: 'mobile_money',
                        child: Text('Mobile Money')),
                    DropdownMenuItem(value: 'other', child: Text('Other')),
                  ],
                  onChanged: (v) =>
                      setDialogState(() => paymentMethod = v ?? 'cash'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Notes', filled: true),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final qty = int.tryParse(qtyCtrl.text);
                final cost = double.tryParse(unitCostCtrl.text);
                if (qty == null || qty < 1) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Quantity must be at least 1.'),
                      backgroundColor: AppTheme.danger));
                  return;
                }
                if (cost == null || cost < 0) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Enter a valid unit cost.'),
                      backgroundColor: AppTheme.danger));
                  return;
                }
                try {
                  await ApiService.updatePurchase(p.id, {
                    'quantity': qty,
                    'purchaseUnit': unit,
                    'unitCost': cost,
                    'supplier': selectedSupplier?.name ?? '',
                    'supplierId': selectedSupplier?.id,
                    'supplierPhone': selectedSupplier?.phone ?? '',
                    'supplierEmail': selectedSupplier?.email ?? '',
                    'invoiceNumber': invoiceCtrl.text.trim(),
                    'paymentMethod': paymentMethod,
                    'notes': notesCtrl.text.trim(),
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Record updated.'),
                      backgroundColor: AppTheme.success));
                  AppEvents.instance.emit('purchases');
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(e.toString()),
                      backgroundColor: AppTheme.danger));
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditHistory(Purchase p) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit History — ${p.productName ?? 'Product'}'),
        content: SizedBox(
          width: 360,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: p.editHistory.length,
            itemBuilder: (ctx, i) {
              final e = p.editHistory[i];
              final changeLines = e.changes.entries
                  .map((entry) {
                    final from = entry.value['from'];
                    final to = entry.value['to'];
                    return '• ${entry.key}: "$from" → "$to"';
                  })
                  .join('\n');
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        '${e.editedByName ?? 'User'} — ${DateFormat('MMM d, yyyy HH:mm').format(e.editedAt.toLocal())}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text(changeLines,
                        style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.secondaryText(context))),
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close')),
        ],
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