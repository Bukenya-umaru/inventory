import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../services/app_events.dart';
import '../../services/auth_provider.dart';
import '../../utils/theme.dart';
import '../../utils/currency.dart';
import '../../utils/download_helper.dart';
import '../../utils/pdf_report_builder.dart';
import '../../widgets/section_search_bar.dart';

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
  bool _perfExpanded = true;
  bool _perfShowAllSales = false;
  bool _perfShowAllDamages = false;
  String _searchQuery = '';

  Map<String, dynamic>? _report;
  Map<String, dynamic>? _inventory;

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
    } else if (event == 'purchases' || event == 'sales' || event == 'expenses' || event == 'damages') {
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

  Future<void> _downloadReport() async {
    if (_report == null) return;
    try {
      final auth = context.read<AuthProvider>();
      final businessName = auth.branding?.businessName ?? '';
      final logoBytes = await ApiService.fetchFile(auth.branding?.businessLogo);
      final bytes = await PdfReportBuilder.build(
        report: _report!,
        dateRangeLabel: _dateRangeLabel(),
        businessName: businessName,
        inventory: _inventory,
        logoBytes: logoBytes,
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
    final auth = context.watch<AuthProvider>();
    final branding = auth.branding;
    final r = _report ?? {};
    final sales = ((r['sales'] as List?) ?? [])
        .where((item) => matchesSectionSearch(_searchQuery, [item]))
        .toList();
    final damages = ((r['damages'] as List?) ?? [])
        .where((item) => matchesSectionSearch(_searchQuery, [item]))
        .toList();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(AppTheme.pad(context, 16)),
        children: [

          Row(
            children: [
              if (branding?.businessLogo != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    ApiService.fileUrl(branding!.businessLogo),
                    height: 40,
                    width: 40,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
                const SizedBox(width: 10),
              ],
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

          _buildSalesPerformance(r, sales, damages),
          SizedBox(height: AppTheme.pad(context, 16)),
        ],
      ),
    );
  }

  /// Tappable "Sales Performance" subsection. Shows totals for the currently
  /// selected period/date range, plus the products sold and damages recorded.
  Widget _buildSalesPerformance(Map r, List sales, List damages) {
    final totalSold = sales.fold<num>(0, (sum, s) => sum + ((s['quantity'] ?? 0) as num)).toInt();
    final totalDamaged = damages.fold<num>(0, (sum, d) => sum + ((d['quantity'] ?? 0) as num)).toInt();
    final totalRevenue = (r['totalRevenue'] ?? 0) as num;
    final totalProfit = (r['totalProfit'] ?? 0) as num;
    final totalExpenses = (r['totalExpenses'] ?? 0) as num;
    final totalDamageLoss = (r['totalDamageLoss'] ?? 0) as num;

    final visiblePerfSales = _perfShowAllSales ? sales : sales.take(5).toList();
    final visiblePerfDamages = _perfShowAllDamages ? damages : damages.take(5).toList();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _perfExpanded = !_perfExpanded),
            child: Padding(
              padding: EdgeInsets.all(AppTheme.pad(context, 12)),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.blueBright(context).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.insights, color: AppTheme.blueBright(context), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Sales Performance',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: AppTheme.fontSize(context, 14))),
                        Text(
                          '${_dateRangeLabel()} • $totalSold sold • $totalDamaged damaged',
                          style: TextStyle(fontSize: AppTheme.fontSize(context, 11), color: AppTheme.secondaryText(context))),
                      ],
                    ),
                  ),
                  Icon(_perfExpanded ? Icons.expand_less : Icons.expand_more,
                    color: AppTheme.secondaryText(context)),
                ],
              ),
            ),
          ),

          if (_perfExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: EdgeInsets.all(AppTheme.pad(context, 12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: _miniCard('Total Sales', Currency.formatWhole(totalRevenue), color: AppTheme.success)),
                      const SizedBox(width: 8),
                      Expanded(child: _miniCard('Total Profits', Currency.formatWhole(totalProfit), color: AppTheme.blueBright(context))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _miniCard('Total Expenses', Currency.formatWhole(totalExpenses), color: AppTheme.warning)),
                      const SizedBox(width: 8),
                      Expanded(child: _miniCard('Damages Recorded', Currency.formatWhole(totalDamageLoss), color: AppTheme.danger)),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Text('Products Sold (${sales.length})',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: AppTheme.fontSize(context, 13))),
                  const SizedBox(height: 6),
                  if (sales.isEmpty)
                    Text('No products sold in this period.',
                      style: TextStyle(fontSize: AppTheme.fontSize(context, 12), color: AppTheme.secondaryText(context)))
                  else ...[
                    ...visiblePerfSales.map((s) => _saleItem(s as Map)),
                    if (sales.length > 5 && !_perfShowAllSales)
                      _showMoreBtn('Show all ${sales.length} sales', () => setState(() => _perfShowAllSales = true)),
                    if (_perfShowAllSales && sales.length > 5)
                      _showMoreBtn('Show less', () => setState(() => _perfShowAllSales = false)),
                  ],
                  const SizedBox(height: 12),

                  Text('Damages Recorded (${damages.length})',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: AppTheme.fontSize(context, 13))),
                  const SizedBox(height: 6),
                  if (damages.isEmpty)
                    Text('No damages recorded in this period.',
                      style: TextStyle(fontSize: AppTheme.fontSize(context, 12), color: AppTheme.secondaryText(context)))
                  else ...[
                    ...visiblePerfDamages.map((d) => _damageItem(d as Map)),
                    if (damages.length > 5 && !_perfShowAllDamages)
                      _showMoreBtn('Show all ${damages.length} damages', () => setState(() => _perfShowAllDamages = true)),
                    if (_perfShowAllDamages && damages.length > 5)
                      _showMoreBtn('Show less', () => setState(() => _perfShowAllDamages = false)),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

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