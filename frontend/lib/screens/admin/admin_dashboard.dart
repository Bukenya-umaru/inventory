import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../services/app_events.dart';
import '../../services/auth_provider.dart';
import '../../utils/theme.dart';
import '../../utils/currency.dart';

/// Accent palette matching the Inventar design.
const Color _kChartBlue = Color(0xFF48A8D8);
const Color _kGreen = Color(0xFF30D878);
const Color _kOrange = Color(0xFFF0A848);
const Color _kPurple = Color(0xFF8B5CF6);
const Color _kRed = Color(0xFFE5484D);

/// Donut palette for Stock by Category.
const List<Color> _kCategoryColors = [
  _kGreen,
  Color(0xFF30D8C0),
  _kChartBlue,
  _kOrange,
  _kPurple,
  Color(0xFFE5484D),
];

class AdminDashboard extends StatefulWidget {
  /// 0 = open Sales, 1 = open Products, 2 = open Reports.
  final void Function(int target)? onSeeAll;

  const AdminDashboard({super.key, this.onSeeAll});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String _range = 'This Month';
  DateTime? _overviewStart;
  DateTime? _overviewEnd;
  bool _allTime = false;

  bool get _usesMonthlyTrend =>
      _allTime ||
      (_overviewStart != null &&
          _overviewEnd != null &&
          _overviewEnd!.difference(_overviewStart!).inDays > 365);

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _overviewStart = DateTime(now.year, now.month, 1);
    _overviewEnd = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
    _load();
    AppEvents.instance.subscribe(_onEvent);
  }

  void _onEvent(String event) {
    if (!mounted) return;
    if (event == 'purchases' || event == 'sales') {
      _load();
    }
  }

  @override
  void dispose() {
    AppEvents.instance.unsubscribe(_onEvent);
    super.dispose();
  }

  Future<void> _load() async {
    final auth = context.read<AuthProvider>();
    final tenantId = auth.user?.tenantId;
    if (tenantId == null) return;
    try {
      final res = await ApiService.getTenantDashboard(
        tenantId,
        startDate: _allTime ? null : _overviewStart,
        endDate: _allTime ? null : _overviewEnd,
        allTime: _allTime,
      );
      setState(() {
        _data = res['dashboard'];
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_data == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.wifi_off_outlined,
              size: 40,
              color: AppTheme.secondaryText(context),
            ),
            const SizedBox(height: 12),
            Text(
              'Failed to load dashboard',
              style: TextStyle(
                fontSize: AppTheme.fontSize(context, 14),
                color: AppTheme.secondaryText(context),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    return RefreshIndicator(onRefresh: _load, child: _buildContent());
  }

  // ---- Data accessors ----

  List<({String date, num revenue, num profit, int salesCount})> _trendData() {
    final trend = _data?['trend'] as List<dynamic>?;
    return (trend ?? [])
        .map(
          (t) => (
            date: (t['date'] ?? '') as String,
            revenue: (t['revenue'] ?? 0) as num,
            profit: (t['profit'] ?? 0) as num,
            salesCount: (t['salesCount'] ?? 0) as int,
          ),
        )
        .toList();
  }

  List<({String name, num value})> _categoryData() {
    final raw = _data?['stockByCategory'] as List<dynamic>? ?? [];
    return raw
        .map(
          (e) => (
            name: (e['name'] ?? 'Uncategorized') as String,
            value: (e['value'] ?? 0) as num,
          ),
        )
        .where((e) => e.value > 0)
        .toList();
  }

  List<({String name, String sku, num stock})> _lowStockItems() {
    final raw = _data?['lowStockItems'] as List<dynamic>? ?? [];
    return raw
        .map(
          (e) => (
            name: (e['name'] ?? 'Unknown') as String,
            sku: (e['sku'] ?? '-') as String,
            stock: (e['stock'] ?? 0) as num,
          ),
        )
        .toList();
  }

  List<
    ({
      String date,
      String type,
      String reference,
      String party,
      num amount,
      String status,
    })
  >
  _recentTransactions() {
    final raw = _data?['recentTransactions'] as List<dynamic>? ?? [];
    return raw
        .map(
          (e) => (
            date: (e['date'] ?? '') as String,
            type: (e['type'] ?? 'Sale') as String,
            reference: (e['reference'] ?? '-') as String,
            party: (e['party'] ?? '-') as String,
            amount: (e['amount'] ?? 0) as num,
            status: (e['status'] ?? 'Completed') as String,
          ),
        )
        .toList();
  }

  // ---- Layout ----

  Widget _buildContent() {
    final d = _data ?? {};
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth >= 900;
    final isExtraWide = screenWidth >= 1280;

    final productCount = '${d['productCount'] ?? 0}';
    final totalStockUnits = Currency.formatWhole(d['totalStockUnits'] ?? 0);
    final lowStock = '${d['lowStockCount'] ?? 0}';
    final totalValue = Currency.formatWhole(d['totalStockValue'] ?? 0);
    final selectedTrend = _trendData();
    final selectedRevenue = selectedTrend.fold<num>(
      0,
      (sum, period) => sum + period.revenue,
    );
    final selectedProfit = selectedTrend.fold<num>(
      0,
      (sum, period) => sum + period.profit,
    );
    final selectedPeriod = _range.startsWith('Custom')
        ? 'Custom Range'
        : _range;

    final overview = _stockOverviewCard();
    final salesActivity = _salesActivityCard();
    final byCategory = _stockByCategoryCard();
    final transactions = _recentTransactionsCard();
    final alerts = _lowStockAlertsCard();
    final userName = context.watch<AuthProvider>().user?.name.trim() ?? '';
    final firstName = userName.isEmpty ? 'there' : userName.split(' ').first;
    final lowStockCount = d['lowStockCount'] as num? ?? 0;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.all(isWide ? 24 : 16),
      children: [
        _welcomeHeader(firstName),
        const SizedBox(height: 20),
        _periodFilters(),
        const SizedBox(height: 12),
        _dashboardNotices(lowStockCount),
        const SizedBox(height: 18),
        _statsRow(
          Currency.formatWhole(selectedRevenue),
          Currency.formatWhole(selectedProfit),
          totalValue,
          productCount,
          totalStockUnits,
          lowStock,
          selectedPeriod,
        ),
        const SizedBox(height: 18),
        if (isExtraWide) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 5, child: overview),
              const SizedBox(width: 14),
              Expanded(flex: 5, child: salesActivity),
              const SizedBox(width: 14),
              Expanded(flex: 4, child: byCategory),
            ],
          ),
          const SizedBox(height: 16),
        ] else if (isWide) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: overview),
              const SizedBox(width: 16),
              Expanded(flex: 2, child: byCategory),
            ],
          ),
          const SizedBox(height: 16),
          salesActivity,
          const SizedBox(height: 16),
        ] else ...[
          overview,
          const SizedBox(height: 16),
          salesActivity,
          const SizedBox(height: 16),
          byCategory,
          const SizedBox(height: 16),
        ],
        if (isWide) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: transactions),
              const SizedBox(width: 16),
              Expanded(flex: 2, child: alerts),
            ],
          ),
        ] else ...[
          transactions,
          const SizedBox(height: 16),
          alerts,
        ],
      ],
    );
  }

  Widget _welcomeHeader(String firstName) {
    final date = DateFormat('EEEE, d MMMM yyyy').format(DateTime.now());
    return LayoutBuilder(
      builder: (context, constraints) {
        final actions = Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () => widget.onSeeAll?.call(2),
              icon: const Icon(Icons.bar_chart_rounded, size: 17),
              label: const Text('Reports'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.textColor(context),
                side: BorderSide(color: AppTheme.borderColor(context)),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => widget.onSeeAll?.call(1),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Product'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF087F5B),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 13,
                ),
              ),
            ),
          ],
        );

        final heading = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Good ${_greeting()}, $firstName',
              style: TextStyle(
                fontSize: AppTheme.fontSize(context, 23),
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
                color: AppTheme.textColor(context),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              '$date - Your business at a glance',
              style: TextStyle(
                fontSize: AppTheme.fontSize(context, 12),
                color: AppTheme.secondaryText(context),
              ),
            ),
          ],
        );

        if (constraints.maxWidth < 650) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [heading, const SizedBox(height: 14), actions],
          );
        }
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: heading),
            const SizedBox(width: 16),
            actions,
          ],
        );
      },
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'morning';
    if (hour < 17) return 'afternoon';
    return 'evening';
  }

  Widget _periodFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          Row(
            children: [
              Icon(
                Icons.calendar_month_outlined,
                size: 16,
                color: AppTheme.secondaryText(context),
              ),
              const SizedBox(width: 6),
              Text(
                'PERIOD',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.7,
                  color: AppTheme.secondaryText(context),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          _periodButton('Today'),
          const SizedBox(width: 7),
          _periodButton('Yesterday'),
          const SizedBox(width: 7),
          _periodButton('This Week'),
          const SizedBox(width: 7),
          _periodButton('This Month'),
          const SizedBox(width: 7),
          _periodButton('This Year'),
          const SizedBox(width: 7),
          _periodButton('Custom'),
          const SizedBox(width: 7),
          _periodButton('All Time'),
        ],
      ),
    );
  }

  Widget _periodButton(String label) {
    final selected =
        _range == label || (label == 'Custom' && _range.startsWith('Custom:'));
    return Material(
      color: selected ? const Color(0xFF087F5B) : AppTheme.cardColor(context),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          if (label == 'Custom') {
            _pickOverviewRange();
          } else if (label == 'All Time') {
            setState(() {
              _range = label;
              _allTime = true;
              _overviewStart = null;
              _overviewEnd = null;
            });
            _load();
          } else {
            _selectRange(label);
          }
        },
        child: SizedBox(
          height: 30,
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected
                    ? const Color(0xFF087F5B)
                    : AppTheme.borderColor(context),
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppTheme.textColor(context),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _dashboardNotices(num lowStockCount) {
    final hasLowStock = lowStockCount > 0;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _noticePill(
          icon: hasLowStock ? Icons.warning_amber_rounded : Icons.check_circle,
          label: hasLowStock
              ? '$lowStockCount Low Stock'
              : 'Stock Levels Healthy',
          color: hasLowStock ? _kOrange : _kGreen,
        ),
        _noticePill(
          icon: Icons.inventory_2_outlined,
          label: '${_data?['productCount'] ?? 0} Products Tracked',
          color: _kChartBlue,
        ),
      ],
    );
  }

  Widget _noticePill({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.textColor(context),
            ),
          ),
        ],
      ),
    );
  }

  // ---- Building blocks ----

  Widget _card({required Widget child, EdgeInsets? padding}) {
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.dividerColor(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _cardHeader(String title, {Widget? action}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: AppTheme.fontSize(context, 16),
              fontWeight: FontWeight.bold,
              color: AppTheme.textColor(context),
            ),
          ),
        ),
        ?action,
      ],
    );
  }

  Widget _viewAll(int target) {
    return GestureDetector(
      onTap: () => widget.onSeeAll?.call(target),
      child: Text(
        'View All',
        style: TextStyle(
          fontSize: AppTheme.fontSize(context, 12),
          fontWeight: FontWeight.w600,
          color: _kChartBlue,
        ),
      ),
    );
  }

  // ---- Section 1: stat cards ----

  Widget _statsRow(
    String revenue,
    String profit,
    String value,
    String products,
    String stock,
    String lowStock,
    String period,
  ) {
    final cards = [
      _statCard('Revenue', revenue, period, _kGreen, Icons.payments_outlined),
      _statCard(
        'Gross Profit',
        profit,
        period,
        _kChartBlue,
        Icons.trending_up_rounded,
      ),
      _statCard(
        'Stock Value',
        value,
        'Current Inventory',
        _kOrange,
        Icons.account_balance_wallet_outlined,
      ),
      _statCard(
        'Total Products',
        products,
        'Active Items',
        _kPurple,
        Icons.inventory_2_outlined,
      ),
      _statCard(
        'Total Stock',
        stock,
        'Units on Hand',
        const Color(0xFF0F9D8A),
        Icons.warehouse_outlined,
      ),
      _statCard(
        'Low Stock',
        lowStock,
        'Need Attention',
        _kRed,
        Icons.warning_amber_outlined,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final cols = w >= 900
            ? 6
            : w >= 650
            ? 3
            : 2;
        const gap = 12.0;
        final cw = (w - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [for (final c in cards) SizedBox(width: cw, child: c)],
        );
      },
    );
  }

  Widget _statCard(
    String label,
    String value,
    String sub,
    Color color,
    IconData icon,
  ) {
    return _card(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 3,
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(13, 12, 13, 13),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: AppTheme.fontSize(context, 11),
                          fontWeight: FontWeight.w600,
                          color: AppTheme.secondaryText(context),
                        ),
                      ),
                      const SizedBox(height: 8),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          value,
                          style: TextStyle(
                            fontSize: AppTheme.fontSize(context, 19),
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textColor(context),
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: AppTheme.fontSize(context, 10),
                          color: AppTheme.secondaryText(context),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---- Section 2: Stock Overview (line chart) ----

  Widget _stockOverviewCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _cardHeader('Revenue & Profit'),
          const SizedBox(height: 10),
          _chartLegend(),
          const SizedBox(height: 10),
          _overviewChart(),
        ],
      ),
    );
  }

  void _selectRange(String value) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = switch (value) {
      'Yesterday' => today.subtract(const Duration(days: 1)),
      'This Week' => today.subtract(Duration(days: today.weekday - 1)),
      'This Year' => DateTime(now.year),
      'This Month' => DateTime(now.year, now.month, 1),
      _ => today,
    };
    final end = value == 'Yesterday'
        ? today.subtract(const Duration(milliseconds: 1))
        : DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
    setState(() {
      _range = value;
      _allTime = false;
      _overviewStart = start;
      _overviewEnd = end;
    });
    _load();
  }

  Future<void> _pickOverviewRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: _overviewStart != null && _overviewEnd != null
          ? DateTimeRange(start: _overviewStart!, end: _overviewEnd!)
          : DateTimeRange(
              start: DateTime(now.year, now.month, 1),
              end: DateTime(now.year, now.month, now.day),
            ),
    );
    if (picked == null || !mounted) return;

    setState(() {
      _range =
          'Custom: ${DateFormat('MMM d').format(picked.start)} - ${DateFormat('MMM d, yyyy').format(picked.end)}';
      _allTime = false;
      _overviewStart = DateTime(
        picked.start.year,
        picked.start.month,
        picked.start.day,
      );
      _overviewEnd = DateTime(
        picked.end.year,
        picked.end.month,
        picked.end.day,
        23,
        59,
        59,
        999,
      );
    });
    _load();
  }

  Widget _overviewChart() {
    var trend = _trendData();
    if (trend.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Text(
            'No sales data yet',
            style: TextStyle(
              fontSize: AppTheme.fontSize(context, 13),
              color: AppTheme.secondaryText(context),
            ),
          ),
        ),
      );
    }
    final values = trend.map((t) => t.revenue.toDouble()).toList();
    final profitValues = trend.map((t) => t.profit.toDouble()).toList();
    if (values.length == 1) values.add(values.first);
    if (profitValues.length == 1) profitValues.add(profitValues.first);
    final maxV = math.max(
      values.reduce(math.max),
      profitValues.reduce(math.max),
    );
    final yMax = _niceMax(maxV);

    final yLabels = [
      _compact(0),
      _compact(yMax * 0.25),
      _compact(yMax * 0.5),
      _compact(yMax * 0.75),
      _compact(yMax),
    ];

    // X labels: evenly spaced dates across the visible range.
    final xCount = values.length <= 7 ? values.length : 5;
    final xLabels = <String>[];
    for (var i = 0; i < xCount; i++) {
      final idx = values.length <= 7
          ? i
          : (i * (values.length - 1) / (xCount - 1)).round();
      xLabels.add(_shortDate(trend[idx].date));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 190,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 46,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final l in yLabels.reversed)
                      Padding(
                        padding: const EdgeInsets.only(right: 6, bottom: 2),
                        child: Text(
                          l,
                          style: TextStyle(
                            fontSize: AppTheme.fontSize(context, 10),
                            color: AppTheme.secondaryText(context),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: CustomPaint(
                  painter: _LineChartPainter(
                    values: values,
                    yMax: yMax,
                    lineColor: _kChartBlue,
                    fillTop: _kChartBlue.withValues(alpha: 0.25),
                    gridColor: AppTheme.dividerColor(context),
                    secondaryValues: profitValues,
                    secondaryLineColor: _kGreen,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            const SizedBox(width: 46),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (final l in xLabels)
                    Text(
                      l,
                      style: TextStyle(
                        fontSize: AppTheme.fontSize(context, 10),
                        color: AppTheme.secondaryText(context),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _chartLegend() {
    return Row(
      children: [
        _legendEntry('Revenue', _kChartBlue),
        const SizedBox(width: 16),
        _legendEntry('Profit', _kGreen),
      ],
    );
  }

  Widget _legendEntry(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: AppTheme.fontSize(context, 11),
            color: AppTheme.secondaryText(context),
          ),
        ),
      ],
    );
  }

  Widget _salesActivityCard() {
    final allTrend = _trendData();
    final trend = allTrend.length > 15
        ? allTrend.sublist(allTrend.length - 15)
        : allTrend;
    final maxCount = trend.fold<int>(
      0,
      (maximum, item) => math.max(maximum, item.salesCount),
    );

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _cardHeader('Sales Activity'),
          const SizedBox(height: 4),
          Text(
            _usesMonthlyTrend
                ? 'Monthly transactions (up to 15 months)'
                : 'Daily transactions (up to 15 days)',
            style: TextStyle(
              fontSize: AppTheme.fontSize(context, 11),
              color: AppTheme.secondaryText(context),
            ),
          ),
          const SizedBox(height: 20),
          if (trend.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  'No sales data yet',
                  style: TextStyle(
                    fontSize: AppTheme.fontSize(context, 13),
                    color: AppTheme.secondaryText(context),
                  ),
                ),
              ),
            )
          else
            SizedBox(
              height: 158,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < trend.length; i++)
                    Expanded(
                      child: Tooltip(
                        message:
                            '${_shortDate(trend[i].date)}: ${trend[i].salesCount} sales',
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Expanded(
                                child: Align(
                                  alignment: Alignment.bottomCenter,
                                  child: Container(
                                    width: double.infinity,
                                    height: maxCount == 0
                                        ? 4
                                        : math.max(
                                            4.0,
                                            trend[i].salesCount /
                                                maxCount *
                                                112,
                                          ),
                                    decoration: BoxDecoration(
                                      color: _kPurple.withValues(
                                        alpha: trend[i].salesCount == 0
                                            ? 0.18
                                            : 0.75,
                                      ),
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(4),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                height: 16,
                                child:
                                    i %
                                                math.max(
                                                  1,
                                                  (trend.length / 5).ceil(),
                                                ) ==
                                            0 ||
                                        i == trend.length - 1
                                    ? Text(
                                        _shortDate(trend[i].date),
                                        maxLines: 1,
                                        overflow: TextOverflow.clip,
                                        style: TextStyle(
                                          fontSize: 9,
                                          color: AppTheme.secondaryText(
                                            context,
                                          ),
                                        ),
                                      )
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  double _niceMax(double v) {
    if (v <= 0) return 10;
    final mag = math.pow(10, (math.log(v) / math.ln10).floor()).toDouble();
    final n = v / mag;
    final nice = n <= 1
        ? 1.0
        : n <= 2
        ? 2.0
        : n <= 2.5
        ? 2.5
        : n <= 5
        ? 5.0
        : 10.0;
    return nice * mag;
  }

  String _compact(num v) {
    if (v >= 1000000) {
      final m = v / 1000000;
      return '${m % 1 == 0 ? m.toStringAsFixed(0) : m.toStringAsFixed(1)}M';
    }
    if (v >= 1000) {
      final k = v / 1000;
      return '${k % 1 == 0 ? k.toStringAsFixed(0) : k.toStringAsFixed(1)}K';
    }
    return v.toStringAsFixed(0);
  }

  String _shortDate(String isoDate) {
    final d = DateTime.tryParse(isoDate);
    if (d == null) return isoDate;
    if (_usesMonthlyTrend) {
      return DateFormat('MMM yy').format(d);
    }
    if (_range == 'Today' || _range == 'Yesterday' || _range == 'This Week') {
      return DateFormat('EEE').format(d);
    }
    return DateFormat('MMM d').format(d);
  }

  // ---- Section 3: Stock by Category (donut) ----

  Widget _stockByCategoryCard() {
    final data = _categoryData();
    final total = data.fold<num>(0, (s, e) => s + e.value);

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _cardHeader('Stock by Category'),
          const SizedBox(height: 16),
          if (data.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  'No stock recorded yet',
                  style: TextStyle(
                    fontSize: AppTheme.fontSize(context, 13),
                    color: AppTheme.secondaryText(context),
                  ),
                ),
              ),
            )
          else ...[
            Center(
              child: SizedBox(
                width: 170,
                height: 170,
                child: CustomPaint(
                  painter: _DonutPainter(
                    segments: [
                      for (var i = 0; i < data.length; i++)
                        (
                          fraction: data[i].value / total,
                          color: _kCategoryColors[i % _kCategoryColors.length],
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            for (var i = 0; i < data.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _kCategoryColors[i % _kCategoryColors.length],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        data[i].name,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: AppTheme.fontSize(context, 13),
                          color: AppTheme.textColor(context),
                        ),
                      ),
                    ),
                    Text(
                      '${(data[i].value / total * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: AppTheme.fontSize(context, 13),
                        fontWeight: FontWeight.w600,
                        color: AppTheme.secondaryText(context),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  // ---- Section 4: Recent Transactions ----

  Widget _recentTransactionsCard() {
    final txs = _recentTransactions();

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _cardHeader('Recent Transactions', action: _viewAll(0)),
          const SizedBox(height: 12),
          if (txs.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No transactions yet',
                  style: TextStyle(
                    fontSize: AppTheme.fontSize(context, 13),
                    color: AppTheme.secondaryText(context),
                  ),
                ),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, c) {
                // The rows use Expanded cells, which need a finite width.
                // Give the table the card's width when it fits, otherwise
                // 620px and let it scroll horizontally.
                final tableWidth = math.max(c.maxWidth, 620.0);
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: tableWidth,
                    child: Column(
                      children: [
                        _txRow([
                          'Date',
                          'Type',
                          'Reference',
                          'Party',
                          'Amount',
                          'Status',
                        ], isHeader: true),
                        for (final t in txs)
                          _txRow([
                            _fmtTxDate(t.date),
                            t.type,
                            t.reference,
                            t.party,
                            Currency.formatWhole(t.amount),
                            t.status,
                          ]),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  String _fmtTxDate(String iso) {
    final d = DateTime.tryParse(iso);
    return d == null ? iso : DateFormat('d MMM yyyy').format(d);
  }

  Widget _txRow(List<String> cells, {bool isHeader = false}) {
    const flexes = [3, 2, 3, 4, 3, 3];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppTheme.dividerColor(context)),
        ),
      ),
      child: Row(
        children: [
          for (var i = 0; i < cells.length; i++)
            Expanded(flex: flexes[i], child: _txCell(cells[i], i, isHeader)),
        ],
      ),
    );
  }

  Widget _txCell(String text, int col, bool isHeader) {
    if (isHeader) {
      return Text(
        text,
        style: TextStyle(
          fontSize: AppTheme.fontSize(context, 12),
          fontWeight: FontWeight.w600,
          color: AppTheme.secondaryText(context),
        ),
      );
    }
    switch (col) {
      case 2: // Reference — blue accent
        return Text(
          text,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: AppTheme.fontSize(context, 12),
            fontWeight: FontWeight.w600,
            color: _kChartBlue,
          ),
        );
      case 5: // Status chip
        return Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _kGreen.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              text,
              style: TextStyle(
                fontSize: AppTheme.fontSize(context, 11),
                fontWeight: FontWeight.w600,
                color: _kGreen,
              ),
            ),
          ),
        );
      default:
        return Text(
          text,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: AppTheme.fontSize(context, 12),
            color: AppTheme.textColor(context),
          ),
        );
    }
  }

  // ---- Section 5: Low Stock Alerts ----

  Widget _lowStockAlertsCard() {
    final items = _lowStockItems();
    const icons = [
      Icons.headphones_outlined,
      Icons.chair_outlined,
      Icons.directions_run_outlined,
      Icons.watch_outlined,
      Icons.devices_other,
    ];

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _cardHeader('Low Stock Alerts', action: _viewAll(1)),
          const SizedBox(height: 12),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_outline, color: _kGreen, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      'All products are well stocked',
                      style: TextStyle(
                        fontSize: AppTheme.fontSize(context, 13),
                        color: AppTheme.secondaryText(context),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            for (var i = 0; i < items.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.dividerColor(context)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppTheme.panelColor(context),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          icons[i % icons.length],
                          size: 22,
                          color: AppTheme.secondaryText(context),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              items[i].name,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: AppTheme.fontSize(context, 13),
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textColor(context),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'SKU: ${items[i].sku}',
                              style: TextStyle(
                                fontSize: AppTheme.fontSize(context, 11),
                                color: AppTheme.secondaryText(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        'Stock: ${items[i].stock}',
                        style: TextStyle(
                          fontSize: AppTheme.fontSize(context, 12),
                          fontWeight: FontWeight.w600,
                          color: _kRed,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

// ---- Custom painters ----

/// Smooth line chart with a gradient fill — no chart library needed.
class _LineChartPainter extends CustomPainter {
  final List<double> values;
  final double yMax;
  final Color lineColor;
  final Color fillTop;
  final Color gridColor;
  final List<double>? secondaryValues;
  final Color secondaryLineColor;

  _LineChartPainter({
    required this.values,
    required this.yMax,
    required this.lineColor,
    required this.fillTop,
    required this.gridColor,
    this.secondaryValues,
    this.secondaryLineColor = Colors.green,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;

    // Horizontal grid lines.
    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (final f in [0.0, 0.25, 0.5, 0.75, 1.0]) {
      canvas.drawLine(
        Offset(0, size.height * f),
        Offset(size.width, size.height * f),
        grid,
      );
    }

    Path linePath(List<double> series) {
      Offset point(int i) => Offset(
        size.width * i / (series.length - 1),
        size.height - (series[i].clamp(0, yMax) / yMax) * (size.height - 4) - 2,
      );

      final path = Path()..moveTo(point(0).dx, point(0).dy);
      for (var i = 1; i < series.length; i++) {
        final prev = point(i - 1);
        final cur = point(i);
        final mid = Offset((prev.dx + cur.dx) / 2, (prev.dy + cur.dy) / 2);
        path.quadraticBezierTo(prev.dx, prev.dy, mid.dx, mid.dy);
      }
      final last = point(series.length - 1);
      path.lineTo(last.dx, last.dy);
      return path;
    }

    final path = linePath(values);

    // Gradient fill under the primary series.
    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [fillTop, fillTop.withValues(alpha: 0.02)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(fillPath, fillPaint);

    canvas.drawPath(
      path,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    final secondary = secondaryValues;
    if (secondary != null && secondary.length >= 2) {
      canvas.drawPath(
        linePath(secondary),
        Paint()
          ..color = secondaryLineColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter old) =>
      !listEquals(old.values, values) ||
      old.yMax != yMax ||
      old.lineColor != lineColor ||
      old.secondaryLineColor != secondaryLineColor ||
      !listEquals(old.secondaryValues, secondaryValues);
}

/// Donut chart drawn with stroked arcs.
class _DonutPainter extends CustomPainter {
  final List<({double fraction, Color color})> segments;

  _DonutPainter({required this.segments});

  @override
  void paint(Canvas canvas, Size size) {
    if (segments.isEmpty) return;
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.22;
    final inset = rect.deflate(paint.strokeWidth / 2);

    var start = -math.pi / 2;
    for (final seg in segments) {
      final sweep = seg.fraction * 2 * math.pi;
      paint.color = seg.color;
      canvas.drawArc(inset, start, sweep, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) => true;
}
