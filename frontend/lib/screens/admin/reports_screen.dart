import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../services/auth_provider.dart';
import '../../utils/theme.dart';
import '../../utils/currency.dart';
import '../../utils/download_helper.dart';
import '../../utils/pdf_report_builder.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String _period = 'daily';
  DateTime? _startDate;
  DateTime? _endDate;
  bool _loading = true;
  bool _showAllSales = false;
  bool _showAllDamages = false;
  bool _showAllProducts = false;
  String _expandedProduct = '';

  Map<String, dynamic>? _report;
  Map<String, dynamic>? _inventory;

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      String? startStr;
      String? endStr;
      if (_startDate != null) startStr = DateFormat('yyyy-MM-dd').format(_startDate!);
      if (_endDate != null) endStr = DateFormat('yyyy-MM-dd').format(_endDate!);

      final results = await Future.wait([
        ApiService.getDetailedReport(
          period: _period,
          startDate: startStr,
          endDate: endStr,
        ),
        ApiService.getInventoryReport(),
      ]);
      final reportRes = results[0];
      final invRes = results[1];
      setState(() {
        _report = reportRes['report'];
        _inventory = invRes['inventory'];
        _loading = false;
      });
    } catch (e) { setState(() => _loading = false); }
  }

  void _setPeriod(String p) {
    final today = _today();
    setState(() {
      _period = p;
      _startDate = null;
      _endDate = null;
      if (p == 'daily') {
        _startDate = today;
        _endDate = today;
      } else if (p == 'weekly') {
        final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
        _startDate = startOfWeek;
        _endDate = today;
      } else if (p == 'monthly') {
        _startDate = DateTime(today.year, today.month, 1);
        _endDate = today;
      } else if (p == 'yearly') {
        _startDate = DateTime(today.year, 1, 1);
        _endDate = today;
      }
    });
    _load();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final today = _today();
    final picked = await showDatePicker(
      context: context,
      initialDate: (isStart ? _startDate : _endDate) ?? today,
      firstDate: DateTime(2020),
      lastDate: today,
    );
    if (picked != null) {
      setState(() {
        _period = 'custom';
        if (isStart) {
          _startDate = picked;
          if (_endDate != null && _endDate!.isBefore(picked)) _endDate = picked;
        } else {
          _endDate = picked;
          if (_startDate != null && _startDate!.isAfter(picked)) _startDate = picked;
        }
      });
      _load();
    }
  }

  String _dateRangeLabel() {
    if (_startDate != null && _endDate != null) {
      if (_startDate == _endDate) return DateFormat('MMM d, yyyy').format(_startDate!);
      return '${DateFormat('MMM d').format(_startDate!)} — ${DateFormat('MMM d, yyyy').format(_endDate!)}';
    }
    return _period[0].toUpperCase() + _period.substring(1);
  }

  // ── PDF Download ──
  Future<void> _downloadReport() async {
    if (_report == null) return;
    try {
      final auth = context.read<AuthProvider>();
      final businessName = auth.branding?.businessName ?? '';
      final bytes = await PdfReportBuilder.build(
        report: _report!,
        dateRangeLabel: _dateRangeLabel(),
        businessName: businessName,
      );
      final fileName = 'report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';
      await downloadBytes(bytes, fileName, 'application/pdf');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export: $e'), backgroundColor: AppTheme.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final r = _report ?? {};
    final inv = _inventory ?? {};
    final sales = (r['sales'] as List?) ?? [];
    final damages = (r['damages'] as List?) ?? [];
    final allProducts = (r['allProducts'] as Map?) ?? {};
    final productBreakdown = (r['productBreakdown'] as Map?) ?? {};
    final damageBreakdown = (r['damageBreakdown'] as Map?) ?? {};
    final visibleSales = _showAllSales ? sales : sales.take(5).toList();
    final visibleDamages = _showAllDamages ? damages : damages.take(5).toList();

    // Sort allProducts: those with sales/damages first, then alphabetically
    final sortedProductKeys = allProducts.keys.toList()..sort((a, b) {
      final pa = allProducts[a] as Map;
      final pb = allProducts[b] as Map;
      final aActive = (pa['quantitySold'] ?? 0) > 0 || (pa['quantityDamaged'] ?? 0) > 0;
      final bActive = (pb['quantitySold'] ?? 0) > 0 || (pb['quantityDamaged'] ?? 0) > 0;
      if (aActive && !bActive) return -1;
      if (!aActive && bActive) return 1;
      return a.compareTo(b);
    });
    final visibleProducts = _showAllProducts ? sortedProductKeys : sortedProductKeys.take(10).toList();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: EdgeInsets.all(AppTheme.pad(context, 16)),
        children: [
          // ── Header + Download ──
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Reports', style: TextStyle(fontSize: AppTheme.fontSize(context, 20), fontWeight: FontWeight.bold)),
                    Text(_dateRangeLabel(), style: TextStyle(fontSize: AppTheme.fontSize(context, 13), color: AppTheme.secondaryText(context))),
                  ],
                ),
              ),
              IconButton(
                onPressed: _downloadReport,
                icon: const Icon(Icons.download),
                tooltip: 'Download PDF',
                style: IconButton.styleFrom(backgroundColor: AppTheme.primary.withValues(alpha: 0.1)),
              ),
            ],
          ),
          SizedBox(height: AppTheme.pad(context, 12)),

          // ── Period Chips ──
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _periodChip('daily', 'Today'),
                _periodChip('weekly', 'This Week'),
                _periodChip('monthly', 'This Month'),
                _periodChip('yearly', 'This Year'),
                const SizedBox(width: 8),
                _datePickerChip('Start', _startDate, () => _pickDate(isStart: true)),
                const SizedBox(width: 4),
                Text('—', style: TextStyle(color: AppTheme.secondaryText(context), fontSize: 14)),
                const SizedBox(width: 4),
                _datePickerChip('End', _endDate, () => _pickDate(isStart: false)),
              ],
            ),
          ),
          SizedBox(height: AppTheme.pad(context, 16)),

          // ── Summary Cards ──
          Row(
            children: [
              Expanded(child: _summaryCard('Revenue', Currency.formatWhole((r['totalRevenue'] ?? 0)), AppTheme.success, Icons.trending_up)),
              const SizedBox(width: 8),
              Expanded(child: _summaryCard('Profit', Currency.formatWhole((r['totalProfit'] ?? 0)), AppTheme.primary, Icons.monetization_on)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _summaryCard('Damage Loss', '-${Currency.formatWhole((r['totalDamageLoss'] ?? 0))}', AppTheme.danger, Icons.warning_amber)),
              const SizedBox(width: 8),
              Expanded(child: _summaryCard('Net Profit', Currency.formatWhole((r['netProfit'] ?? 0)), Colors.purple, Icons.account_balance_wallet)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _summaryCard('Sales Count', '${r['totalSales'] ?? 0}', AppTheme.blueBright(context), Icons.shopping_cart)),
              const SizedBox(width: 8),
              Expanded(child: _summaryCard('Damage Reports', '${r['totalDamageReports'] ?? 0}', AppTheme.warning, Icons.broken_image)),
            ],
          ),
          SizedBox(height: AppTheme.pad(context, 20)),

          // ── Per-Product Detail Cards ──
          if (allProducts.isNotEmpty) ...[
            _sectionHeader('Product Details (${allProducts.length})'),
            const SizedBox(height: 8),
            ...visibleProducts.map((name) => _productDetailCard(name, allProducts[name] as Map)),
            if (sortedProductKeys.length > 10 && !_showAllProducts)
              _showMoreBtn('Show all ${sortedProductKeys.length} products', () => setState(() => _showAllProducts = true)),
            if (_showAllProducts && sortedProductKeys.length > 10)
              _showMoreBtn('Show less', () => setState(() => _showAllProducts = false)),
            SizedBox(height: AppTheme.pad(context, 20)),
          ],

          // ── Product Sales Breakdown Table ──
          if (productBreakdown.isNotEmpty) ...[
            _sectionHeader('Sales by Product'),
            const SizedBox(height: 8),
            _buildProductBreakdown(productBreakdown),
            SizedBox(height: AppTheme.pad(context, 20)),
          ],

          // ── Product Damage Breakdown Table ──
          if (damageBreakdown.isNotEmpty) ...[
            _sectionHeader('Damages by Product'),
            const SizedBox(height: 8),
            _buildDamageBreakdown(damageBreakdown),
            SizedBox(height: AppTheme.pad(context, 20)),
          ],

          // ── Sales List ──
          if (sales.isNotEmpty) ...[
            _sectionHeader('All Sales (${sales.length})'),
            const SizedBox(height: 8),
            ...visibleSales.map((s) => _saleItem(s)),
            if (sales.length > 5 && !_showAllSales)
              _showMoreBtn('Show all ${sales.length} sales', () => setState(() => _showAllSales = true)),
            if (_showAllSales && sales.length > 5)
              _showMoreBtn('Show less', () => setState(() => _showAllSales = false)),
            SizedBox(height: AppTheme.pad(context, 20)),
          ],

          // ── Damages List ──
          if (damages.isNotEmpty) ...[
            _sectionHeader('All Damages (${damages.length})'),
            const SizedBox(height: 8),
            ...visibleDamages.map((d) => _damageItem(d)),
            if (damages.length > 5 && !_showAllDamages)
              _showMoreBtn('Show all ${damages.length} damages', () => setState(() => _showAllDamages = true)),
            if (_showAllDamages && damages.length > 5)
              _showMoreBtn('Show less', () => setState(() => _showAllDamages = false)),
            SizedBox(height: AppTheme.pad(context, 20)),
          ],

          // ── Inventory ──
          _sectionHeader('Inventory Overview'),
          SizedBox(height: AppTheme.pad(context, 8)),
          Row(
            children: [
              Expanded(child: _miniCard('Products', '${inv['totalProducts'] ?? 0}')),
              const SizedBox(width: 8),
              Expanded(child: _miniCard('Stock Value', Currency.formatWhole((inv['totalStockValue'] ?? 0)))),
              const SizedBox(width: 8),
              Expanded(child: _miniCard('Low Stock', '${inv['lowStockCount'] ?? 0}', color: AppTheme.warning)),
            ],
          ),
          SizedBox(height: AppTheme.pad(context, 16)),
        ],
      ),
    );
  }

  // ── Per-Product Detail Card ──
  Widget _productDetailCard(String name, Map p) {
    final isExpanded = _expandedProduct == name;
    final qtySold = p['quantitySold'] ?? 0;
    final qtyDamaged = p['quantityDamaged'] ?? 0;
    final revenue = p['revenue'] ?? 0.0;
    final profit = p['profit'] ?? 0.0;
    final loss = p['loss'] ?? 0.0;
    final stock = p['currentStock'] ?? 0;
    final boxes = p['stockBoxes'] ?? 0;
    final totalStock = p['totalStockPieces'] ?? 0;
    final minStock = p['minimumStock'] ?? 0;
    final costPrice = p['costPrice'] ?? 0.0;
    final sellPrice = p['sellingPrice'] ?? 0.0;
    final margin = revenue > 0 ? (profit / revenue * 100) : 0.0;
    final category = p['category'] ?? '';
    final hasActivity = qtySold > 0 || qtyDamaged > 0;
    final isLowStock = totalStock <= minStock && totalStock > 0;

    Color statusColor;
    IconData statusIcon;
    if (totalStock == 0 && qtySold == 0 && qtyDamaged == 0) {
      statusColor = AppTheme.secondaryText(context);
      statusIcon = Icons.inventory_2_outlined;
    } else if (isLowStock) {
      statusColor = AppTheme.warning;
      statusIcon = Icons.warning_amber;
    } else {
      statusColor = AppTheme.success;
      statusIcon = Icons.check_circle_outline;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => setState(() => _expandedProduct = isExpanded ? '' : name),
        child: Padding(
          padding: EdgeInsets.all(AppTheme.pad(context, 12)),
          child: Column(
            children: [
              // ── Header Row ──
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(statusIcon, color: statusColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: AppTheme.fontSize(context, 14))),
                        if (category.isNotEmpty)
                          Text(category, style: TextStyle(fontSize: 11, color: AppTheme.secondaryText(context))),
                      ],
                    ),
                  ),
                  if (hasActivity)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text('Active', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.primary)),
                    ),
                  const SizedBox(width: 8),
                  Icon(isExpanded ? Icons.expand_less : Icons.expand_more, color: AppTheme.secondaryText(context)),
                ],
              ),

              // ── Quick Stats Row ──
              const SizedBox(height: 8),
              Row(
                children: [
                  _miniStat('Stock', '$totalStock', stock == 0 ? AppTheme.danger : isLowStock ? AppTheme.warning : AppTheme.success),
                  _miniStat('Sold', '$qtySold', qtySold > 0 ? AppTheme.primary : AppTheme.secondaryText(context)),
                  _miniStat('Damaged', '$qtyDamaged', qtyDamaged > 0 ? AppTheme.danger : AppTheme.secondaryText(context)),
                  _miniStat('Revenue', Currency.formatWhole(revenue), revenue > 0 ? AppTheme.success : AppTheme.secondaryText(context)),
                  _miniStat('Profit', Currency.formatWhole(profit), profit > 0 ? AppTheme.success : AppTheme.secondaryText(context)),
                ],
              ),

              // ── Expanded Details ──
              if (isExpanded) ...[
                const Divider(height: 16),
                _detailGrid(p),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniStat(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: color)),
          Text(label, style: TextStyle(fontSize: 9, color: AppTheme.secondaryText(context))),
        ],
      ),
    );
  }

  Widget _detailGrid(Map p) {
    final costPrice = p['costPrice'] ?? 0.0;
    final sellPrice = p['sellingPrice'] ?? 0.0;
    final revenue = p['revenue'] ?? 0.0;
    final profit = p['profit'] ?? 0.0;
    final loss = p['loss'] ?? 0.0;
    final costOfGoods = p['costOfGoodsSold'] ?? 0.0;
    final margin = revenue > 0 ? (profit / revenue * 100) : 0.0;
    final stock = p['currentStock'] ?? 0;
    final boxes = p['stockBoxes'] ?? 0;
    final upb = p['unitsPerBox'] ?? 1;
    final unit = p['sellingUnit'] ?? 'piece';
    final minStock = p['minimumStock'] ?? 0;
    final totalStock = p['totalStockPieces'] ?? 0;

    return Column(
      children: [
        // Pricing
        _detailRow('Cost Price', Currency.format(costPrice)),
        _detailRow('Selling Price', Currency.format(sellPrice)),
        if (unit == 'box') ...[
          _detailRow('Unit Type', 'Box (${upb} pcs/box)'),
          _detailRow('Boxes in Stock', '$boxes'),
        ],
        _detailRow('Pieces in Stock', '$stock'),
        _detailRow('Total Stock (pcs)', '$totalStock'),
        _detailRow('Minimum Stock', '$minStock'),
        const Divider(height: 12),
        // Sales
        _detailRow('Quantity Sold', '${p['quantitySold'] ?? 0}'),
        _detailRow('Sales Revenue', Currency.formatWhole(revenue)),
        _detailRow('Cost of Goods Sold', Currency.formatWhole(costOfGoods)),
        _detailRow('Sales Profit', Currency.formatWhole(profit), color: AppTheme.success),
        _detailRow('Profit Margin', '${margin.toStringAsFixed(1)}%', color: margin > 0 ? AppTheme.success : AppTheme.danger),
        _detailRow('Sales Transactions', '${p['salesCount'] ?? 0}'),
        const Divider(height: 12),
        // Damages
        _detailRow('Quantity Damaged', '${p['quantityDamaged'] ?? 0}', color: (p['quantityDamaged'] ?? 0) > 0 ? AppTheme.danger : null),
        _detailRow('Damage Loss', '-${Currency.formatWhole(loss)}', color: loss > 0 ? AppTheme.danger : null),
        _detailRow('Damage Reports', '${p['damageCount'] ?? 0}'),
      ],
    );
  }

  Widget _detailRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(fontSize: 12, color: AppTheme.secondaryText(context)))),
          Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color ?? AppTheme.textColor(context))),
        ],
      ),
    );
  }

  // ── Existing Widgets ──

  Widget _periodChip(String value, String label) {
    final isActive = _period == value;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label, style: TextStyle(fontSize: AppTheme.fontSize(context, 12))),
        selected: isActive,
        onSelected: (_) => _setPeriod(value),
        selectedColor: AppTheme.primary,
        labelStyle: TextStyle(color: isActive ? Colors.white : AppTheme.textColor(context)),
      ),
    );
  }

  Widget _datePickerChip(String label, DateTime? date, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_today, size: 14, color: AppTheme.secondaryText(context)),
            const SizedBox(width: 4),
            Text(
              date != null ? DateFormat('MMM d, yyyy').format(date) : label,
              style: TextStyle(fontSize: 12, color: AppTheme.secondaryText(context)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryCard(String label, String value, Color color, IconData icon) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(AppTheme.pad(context, 14)),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 11, color: AppTheme.secondaryText(context))),
                  const SizedBox(height: 2),
                  Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Text(title, style: TextStyle(fontSize: AppTheme.fontSize(context, 16), fontWeight: FontWeight.bold));
  }

  Widget _buildProductBreakdown(Map breakdown) {
    final entries = breakdown.entries.toList()..sort((a, b) => (b.value['profit'] ?? 0).compareTo(a.value['profit'] ?? 0));
    return Card(
      child: Padding(
        padding: EdgeInsets.all(AppTheme.pad(context, 12)),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(flex: 3, child: Text('Product', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.secondaryText(context)))),
                  Expanded(flex: 2, child: Text('Revenue', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.secondaryText(context)))),
                  Expanded(flex: 2, child: Text('Profit', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.secondaryText(context)))),
                  Expanded(flex: 1, child: Text('Qty', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.secondaryText(context)))),
                ],
              ),
            ),
            const Divider(height: 1),
            ...entries.map((e) {
              final data = e.value as Map;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(flex: 3, child: Text(e.key, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
                    Expanded(flex: 2, child: Text(Currency.formatWhole(data['revenue'] ?? 0), textAlign: TextAlign.right, style: TextStyle(fontSize: 12, color: AppTheme.primaryBright(context)))),
                    Expanded(flex: 2, child: Text(Currency.formatWhole(data['profit'] ?? 0), textAlign: TextAlign.right, style: TextStyle(fontSize: 12, color: AppTheme.success))),
                    Expanded(flex: 1, child: Text('${data['quantity'] ?? 0}', textAlign: TextAlign.right, style: TextStyle(fontSize: 12))),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildDamageBreakdown(Map breakdown) {
    final entries = breakdown.entries.toList()..sort((a, b) => (b.value['loss'] ?? 0).compareTo(a.value['loss'] ?? 0));
    return Card(
      child: Padding(
        padding: EdgeInsets.all(AppTheme.pad(context, 12)),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(flex: 3, child: Text('Product', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.secondaryText(context)))),
                  Expanded(flex: 2, child: Text('Loss', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.secondaryText(context)))),
                  Expanded(flex: 1, child: Text('Qty', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.secondaryText(context)))),
                ],
              ),
            ),
            const Divider(height: 1),
            ...entries.map((e) {
              final data = e.value as Map;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(flex: 3, child: Text(e.key, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
                    Expanded(flex: 2, child: Text('-${Currency.formatWhole(data['loss'] ?? 0)}', textAlign: TextAlign.right, style: TextStyle(fontSize: 12, color: AppTheme.danger))),
                    Expanded(flex: 1, child: Text('${data['quantity'] ?? 0}', textAlign: TextAlign.right, style: TextStyle(fontSize: 12))),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _saleItem(Map s) {
    final date = s['saleDate'] != null ? DateFormat('MMM d, HH:mm').format(DateTime.parse(s['saleDate'])) : '';
    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        dense: true,
        leading: Icon(Icons.shopping_cart, size: 18, color: AppTheme.success),
        title: Text(s['productName'] ?? 'Unknown', maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: AppTheme.fontSize(context, 13))),
        subtitle: Text(
          '${s['quantity']} ${s['saleUnit'] == 'box' ? 'box' : 'pc'} @ ${Currency.formatWhole((s['unitPrice'] ?? 0))} • $date'
          '${s['customerName'] != null ? ' • ${s['customerName']}' : ''}',
          maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: AppTheme.fontSize(context, 11))),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(Currency.formatWhole((s['totalAmount'] ?? 0)),
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: AppTheme.fontSize(context, 13))),
            const SizedBox(width: 4),
            Text('P: ${Currency.formatWhole((s['profit'] ?? 0))}',
              style: TextStyle(fontSize: AppTheme.fontSize(context, 10), color: AppTheme.success)),
          ],
        ),
      ),
    );
  }

  Widget _damageItem(Map d) {
    final date = d['reportDate'] != null ? DateFormat('MMM d, HH:mm').format(DateTime.parse(d['reportDate'])) : '';
    return Card(
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        dense: true,
        leading: Icon(Icons.warning_amber, size: 18, color: AppTheme.warning),
        title: Text(d['productName'] ?? 'Unknown', maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: AppTheme.fontSize(context, 13))),
        subtitle: Text(
          '${d['quantity']} ${d['damageUnit'] == 'box' ? 'box' : 'pc'} • ${d['reason']} • $date',
          maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: AppTheme.fontSize(context, 11))),
        trailing: Text('-${Currency.formatWhole((d['estimatedLoss'] ?? 0))}',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: AppTheme.fontSize(context, 13), color: AppTheme.danger)),
      ),
    );
  }

  Widget _miniCard(String label, String value, {Color? color}) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(AppTheme.pad(context, 12)),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: AppTheme.fontSize(context, 18), fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: AppTheme.fontSize(context, 12), color: AppTheme.secondaryText(context))),
          ],
        ),
      ),
    );
  }

  Widget _showMoreBtn(String text, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Center(
        child: TextButton(
          onPressed: onTap,
          child: Text(text, style: TextStyle(color: AppTheme.primary, fontSize: 13)),
        ),
      ),
    );
  }
}
