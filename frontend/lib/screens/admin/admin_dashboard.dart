import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../services/app_events.dart';
import '../../services/auth_provider.dart';
import '../../utils/theme.dart';
import '../../utils/currency.dart';

/// Accent palette matching the dashboard mock.
const Color _kChartBlue = Color(0xFF2563EB);
const Color _kGreen = Color(0xFF16A34A);
const Color _kOrange = Color(0xFFF59E0B);
const Color _kPurple = Color(0xFF8B5CF6);
const Color _kRed = Color(0xFFDC2626);

/// Donut palette for Stock by Category.
const List<Color> _kCategoryColors = [
  _kChartBlue,
  _kGreen,
  _kOrange,
  _kPurple,
  Color(0xFF0EA5E9),
  Color(0xFFEF4444),
];

class AdminDashboard extends StatefulWidget {
  /// 0 = open Sales, 1 = open Products (used by the "View All" links).
  final void Function(int target)? onSeeAll;

  const AdminDashboard({super.key, this.onSeeAll});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String _range = 'This Month'; // Stock Overview filter

  @override
  void initState() {
    super.initState();
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
      final res = await ApiService.getTenantDashboard(tenantId);
      setState(() { _data = res['dashboard']; _loading = false; });
    } catch (e) { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_data == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_outlined,
                size: 40, color: AppTheme.secondaryText(context)),
            const SizedBox(height: 12),
            Text('Failed to load dashboard',
              style: TextStyle(
                fontSize: AppTheme.fontSize(context, 14),
                color: AppTheme.secondaryText(context))),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: _buildContent(),
    );
  }

  // ---- Data accessors ----

  List<({String date, num revenue, num profit, int salesCount})> _trendData() {
    final trend = _data?['trend'] as List<dynamic>?;
    return (trend ?? [])
        .map((t) => (
              date: (t['date'] ?? '') as String,
              revenue: (t['revenue'] ?? 0) as num,
              profit: (t['profit'] ?? 0) as num,
              salesCount: (t['salesCount'] ?? 0) as int,
            ))
        .toList();
  }

  List<({String name, num value})> _categoryData() {
    final raw = _data?['stockByCategory'] as List<dynamic>? ?? [];
    return raw
        .map((e) => (
              name: (e['name'] ?? 'Uncategorized') as String,
              value: (e['value'] ?? 0) as num,
            ))
        .where((e) => e.value > 0)
        .toList();
  }

  List<({String name, String sku, num stock})> _lowStockItems() {
    final raw = _data?['lowStockItems'] as List<dynamic>? ?? [];
    return raw
        .map((e) => (
              name: (e['name'] ?? 'Unknown') as String,
              sku: (e['sku'] ?? '-') as String,
              stock: (e['stock'] ?? 0) as num,
            ))
        .toList();
  }

  List<({String date, String type, String reference, String party, num amount, String status})>
      _recentTransactions() {
    final raw = _data?['recentTransactions'] as List<dynamic>? ?? [];
    return raw
        .map((e) => (
              date: (e['date'] ?? '') as String,
              type: (e['type'] ?? 'Sale') as String,
              reference: (e['reference'] ?? '-') as String,
              party: (e['party'] ?? '-') as String,
              amount: (e['amount'] ?? 0) as num,
              status: (e['status'] ?? 'Completed') as String,
            ))
        .toList();
  }

  // ---- Layout ----

  Widget _buildContent() {
    final d = _data ?? {};
    final isWide = MediaQuery.of(context).size.width >= 900;

    final productCount = '${d['productCount'] ?? 0}';
    final totalStockUnits = Currency.formatWhole(d['totalStockUnits'] ?? 0);
    final lowStock = '${d['lowStockCount'] ?? 0}';
    final totalValue = Currency.formatWhole(d['totalStockValue'] ?? 0);

    final overview = _stockOverviewCard();
    final byCategory = _stockByCategoryCard();
    final transactions = _recentTransactionsCard();
    final alerts = _lowStockAlertsCard();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.all(isWide ? 24 : 16),
      children: [
        _statsRow(productCount, totalStockUnits, lowStock, totalValue),
        const SizedBox(height: 16),
        if (isWide) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: overview),
              const SizedBox(width: 16),
              Expanded(flex: 2, child: byCategory),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: transactions),
              const SizedBox(width: 16),
              Expanded(flex: 2, child: alerts),
            ],
          ),
        ] else ...[
          overview,
          const SizedBox(height: 16),
          byCategory,
          const SizedBox(height: 16),
          transactions,
          const SizedBox(height: 16),
          alerts,
        ],
      ],
    );
  }

  // ---- Building blocks ----

  Widget _card({required Widget child, EdgeInsets? padding}) {
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.dividerColor(context)),
      ),
      child: child,
    );
  }

  Widget _cardHeader(String title, {Widget? action}) {
    return Row(
      children: [
        Expanded(
          child: Text(title,
            style: TextStyle(
              fontSize: AppTheme.fontSize(context, 16),
              fontWeight: FontWeight.bold,
              color: AppTheme.textColor(context))),
        ),
        ?action,
      ],
    );
  }

  Widget _viewAll(int target) {
    return GestureDetector(
      onTap: () => widget.onSeeAll?.call(target),
      child: Text('View All',
        style: TextStyle(
          fontSize: AppTheme.fontSize(context, 12),
          fontWeight: FontWeight.w600,
          color: _kChartBlue)),
    );
  }

  // ---- Section 1: stat cards ----

  Widget _statsRow(String products, String stock, String lowStock, String value) {
    final cards = [
      _statCard('Total Products', products, 'Active Products',
          _kChartBlue, Icons.inventory_2_outlined),
      _statCard('Total Stock', stock, 'In Hand', _kGreen, Icons.circle),
      _statCard('Low Stock', lowStock, 'Products', _kOrange,
          Icons.warning_amber_outlined),
      _statCard('Total Value', value, 'Stock Value', _kPurple,
          Icons.attach_money),
    ];

    return LayoutBuilder(builder: (context, constraints) {
      final w = constraints.maxWidth;
      final cols = w >= 720 ? 4 : 2;
      final cw = (w - 16 * (cols - 1)) / cols;
      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [for (final c in cards) SizedBox(width: cw, child: c)],
      );
    });
  }

  Widget _statCard(String label, String value, String sub, Color color, IconData icon) {
    return _card(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label,
                  style: TextStyle(
                    fontSize: AppTheme.fontSize(context, 13),
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textColor(context))),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(value,
                    style: TextStyle(
                      fontSize: AppTheme.fontSize(context, 22),
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textColor(context)))),
                const SizedBox(height: 4),
                Text(sub,
                  style: TextStyle(
                    fontSize: AppTheme.fontSize(context, 11),
                    color: AppTheme.secondaryText(context))),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 24),
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
          _cardHeader('Stock Overview', action: _rangeSelector()),
          const SizedBox(height: 16),
          _overviewChart(),
        ],
      ),
    );
  }

  Widget _rangeSelector() {
    return PopupMenuButton<String>(
      onSelected: (v) => setState(() => _range = v),
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'Last 7 Days', child: Text('Last 7 Days')),
        PopupMenuItem(value: 'This Month', child: Text('This Month')),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.borderColor(context)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_range,
              style: TextStyle(
                fontSize: AppTheme.fontSize(context, 12),
                color: AppTheme.textColor(context))),
            const SizedBox(width: 4),
            Icon(Icons.expand_more,
                size: 16, color: AppTheme.secondaryText(context)),
          ],
        ),
      ),
    );
  }

  Widget _overviewChart() {
    var trend = _trendData();
    if (trend.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Text('No sales data yet',
            style: TextStyle(
              fontSize: AppTheme.fontSize(context, 13),
              color: AppTheme.secondaryText(context))),
        ),
      );
    }
    if (_range == 'Last 7 Days' && trend.length > 7) {
      trend = trend.sublist(trend.length - 7);
    }

    final values = trend.map((t) => t.revenue.toDouble()).toList();
    if (values.length == 1) values.add(values.first);
    final maxV = values.reduce(math.max);
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

    final chartColor = AppTheme.textColor(context);

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
                        child: Text(l,
                          style: TextStyle(
                            fontSize: AppTheme.fontSize(context, 10),
                            color: AppTheme.secondaryText(context))),
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
                    Text(l,
                      style: TextStyle(
                        fontSize: AppTheme.fontSize(context, 10),
                        color: AppTheme.secondaryText(context))),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: 2, child: Text('', style: TextStyle(color: chartColor, fontSize: 1))),
      ],
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
    if (_range == 'Last 7 Days') {
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
                child: Text('No stock recorded yet',
                  style: TextStyle(
                    fontSize: AppTheme.fontSize(context, 13),
                    color: AppTheme.secondaryText(context))),
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
                      child: Text(data[i].name,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: AppTheme.fontSize(context, 13),
                          color: AppTheme.textColor(context))),
                    ),
                    Text(
                      '${(data[i].value / total * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: AppTheme.fontSize(context, 13),
                        fontWeight: FontWeight.w600,
                        color: AppTheme.secondaryText(context))),
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
                child: Text('No transactions yet',
                  style: TextStyle(
                    fontSize: AppTheme.fontSize(context, 13),
                    color: AppTheme.secondaryText(context))),
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
                        _txRow(['Date', 'Type', 'Reference', 'Party', 'Amount', 'Status'],
                            isHeader: true),
                        for (final t in txs) _txRow([
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
            Expanded(
              flex: flexes[i],
              child: _txCell(cells[i], i, isHeader),
            ),
        ],
      ),
    );
  }

  Widget _txCell(String text, int col, bool isHeader) {
    if (isHeader) {
      return Text(text,
        style: TextStyle(
          fontSize: AppTheme.fontSize(context, 12),
          fontWeight: FontWeight.w600,
          color: AppTheme.secondaryText(context)));
    }
    switch (col) {
      case 2: // Reference — blue accent
        return Text(text,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: AppTheme.fontSize(context, 12),
            fontWeight: FontWeight.w600,
            color: _kChartBlue));
      case 5: // Status chip
        return Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _kGreen.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(text,
              style: TextStyle(
                fontSize: AppTheme.fontSize(context, 11),
                fontWeight: FontWeight.w600,
                color: _kGreen)),
          ),
        );
      default:
        return Text(text,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: AppTheme.fontSize(context, 12),
            color: AppTheme.textColor(context)));
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
                    Icon(Icons.check_circle_outline,
                        color: _kGreen, size: 18),
                    const SizedBox(width: 6),
                    Text('All products are well stocked',
                      style: TextStyle(
                        fontSize: AppTheme.fontSize(context, 13),
                        color: AppTheme.secondaryText(context))),
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
                        child: Icon(icons[i % icons.length],
                          size: 22,
                          color: AppTheme.secondaryText(context)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(items[i].name,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: AppTheme.fontSize(context, 13),
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textColor(context))),
                            const SizedBox(height: 2),
                            Text('SKU: ${items[i].sku}',
                              style: TextStyle(
                                fontSize: AppTheme.fontSize(context, 11),
                                color: AppTheme.secondaryText(context))),
                          ],
                        ),
                      ),
                      Text('Stock: ${items[i].stock}',
                        style: TextStyle(
                          fontSize: AppTheme.fontSize(context, 12),
                          fontWeight: FontWeight.w600,
                          color: _kRed)),
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

  _LineChartPainter({
    required this.values,
    required this.yMax,
    required this.lineColor,
    required this.fillTop,
    required this.gridColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;

    Offset p(int i) => Offset(
          size.width * i / (values.length - 1),
          size.height -
              (values[i].clamp(0, yMax) / yMax) * (size.height - 4) -
              2,
        );

    // Horizontal grid lines.
    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (final f in [0.0, 0.25, 0.5, 0.75, 1.0]) {
      canvas.drawLine(Offset(0, size.height * f),
          Offset(size.width, size.height * f), grid);
    }

    // Smooth curve through midpoints.
    final path = Path()..moveTo(p(0).dx, p(0).dy);
    for (var i = 1; i < values.length; i++) {
      final prev = p(i - 1);
      final cur = p(i);
      final mid = Offset((prev.dx + cur.dx) / 2, (prev.dy + cur.dy) / 2);
      path.quadraticBezierTo(prev.dx, prev.dy, mid.dx, mid.dy);
    }
    final last = p(values.length - 1);
    path.lineTo(last.dx, last.dy);

    // Gradient fill under the curve.
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

    // The line itself.
    canvas.drawPath(
      path,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter old) =>
      old.values.length != values.length ||
      old.yMax != yMax ||
      old.lineColor != lineColor;
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
