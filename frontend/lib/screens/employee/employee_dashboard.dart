import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_provider.dart';
import '../../services/api_service.dart';
import '../../services/app_events.dart';
import '../../utils/theme.dart';
import '../../utils/currency.dart';
import '../../widgets/period_filter_chip.dart';

class EmployeeDashboard extends StatefulWidget {
  const EmployeeDashboard({super.key});
  @override
  State<EmployeeDashboard> createState() => _EmployeeDashboardState();
}

class _EmployeeDashboardState extends State<EmployeeDashboard> {
  Map<String, dynamic>? _summary;
  bool _loading = true;
  String _salesRange = 'Today'; // Sales Activity filter: Today | Weekly | Monthly
  List<bool> _salesMetrics = [true, true, true]; // Revenue, Profit, Sales Count

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
    try {
      final res = await ApiService.getReportSummary();
      setState(() { _summary = res['summary']; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWide = size.width >= 900;
    final auth = context.watch<AuthProvider>();
    final branding = auth.branding;

    if (_loading) return const Center(child: CircularProgressIndicator());

    return RefreshIndicator(
      onRefresh: _load,
      child: isWide
          ? _wideLayout(context, auth, branding)
          : _mobileLayout(context, auth, branding),
    );
  }

  // ---- Building blocks (same design language as the admin dashboard) ----

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

  Widget _panel({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.panelColor(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }

  Widget _statTile(String label, String value, Color valueColor, IconData icon) {
    return _card(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: valueColor),
              const SizedBox(width: 4),
              Expanded(
                child: Text(label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: AppTheme.fontSize(context, 11),
                    color: AppTheme.secondaryText(context))),
              ),
            ],
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value,
              style: TextStyle(
                fontSize: AppTheme.fontSize(context, 17),
                fontWeight: FontWeight.bold,
                color: valueColor)),
          ),
        ],
      ),
    );
  }

  // ---- Sales Activity card with working filter (period + metrics) ----

  Future<void> _showSalesActivityFilter() async {
    var range = _salesRange;
    var metrics = List<bool>.from(_salesMetrics);
    const labels = ['Revenue', 'Profit', 'Sales Count'];

    final applied = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppTheme.cardColor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text('Filter Sales Activity',
                        style: TextStyle(
                          fontSize: AppTheme.fontSize(sheetContext, 16),
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textColor(sheetContext))),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(sheetContext, false),
                      icon: Icon(Icons.close,
                        color: AppTheme.secondaryText(sheetContext))),
                  ],
                ),
                const SizedBox(height: 4),
                Text('PERIOD',
                  style: TextStyle(
                    fontSize: AppTheme.fontSize(sheetContext, 11),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    color: AppTheme.secondaryText(sheetContext))),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final r in const ['Today', 'Weekly', 'Monthly'])
                      PeriodFilterChip(
                        label: r,
                        selected: range == r,
                        onTap: () => setSheetState(() => range = r),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text('METRICS SHOWN',
                  style: TextStyle(
                    fontSize: AppTheme.fontSize(sheetContext, 11),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    color: AppTheme.secondaryText(sheetContext))),
                const SizedBox(height: 4),
                ...List.generate(3, (i) => CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: AppTheme.dashNavyColor(sheetContext),
                  title: Text(labels[i],
                    style: TextStyle(
                      fontSize: AppTheme.fontSize(sheetContext, 14),
                      color: AppTheme.textColor(sheetContext))),
                  value: metrics[i],
                  onChanged: (v) => setSheetState(() => metrics[i] = v ?? false),
                )),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => setSheetState(() {
                          range = 'Today';
                          metrics = [true, true, true];
                        }),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: AppTheme.borderColor(sheetContext))),
                        child: Text('Reset',
                          style: TextStyle(
                            color: AppTheme.secondaryText(sheetContext))),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(sheetContext, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.dashNavyColor(sheetContext),
                          foregroundColor: Colors.white),
                        child: const Text('Apply'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );

    if (applied == true && mounted) {
      setState(() {
        _salesRange = range;
        _salesMetrics = metrics;
      });
    }
  }

  ({List<String> values, List<Color> colors, List<IconData> icons, String subtitle})
      _salesActivityData() {
    final d = _summary ?? {};
    final today = d['today'];
    final monthly = d['monthly'];

    String fmtTodayRevenue = Currency.formatWhole((today?['revenue'] ?? 0));
    String fmtTodayProfit = Currency.formatWhole((today?['profit'] ?? 0));
    String fmtTodayCount = '${today?['salesCount'] ?? 0}';
    String fmtMonthRevenue = Currency.formatWhole((monthly?['revenue'] ?? 0));
    String fmtMonthProfit = Currency.formatWhole((monthly?['profit'] ?? 0));
    String fmtMonthCount = '${monthly?['salesCount'] ?? 0}';

    final week = _lastWeekTotals();
    String fmtWeekRevenue = Currency.formatWhole(week.revenue);
    String fmtWeekProfit = Currency.formatWhole(week.profit);
    String fmtWeekCount = '${week.salesCount}';

    const icons = [
      Icons.payments_outlined,
      Icons.trending_up,
      Icons.receipt_long_outlined,
    ];
    final colors = [
      AppTheme.dashNavyColor(context),
      AppTheme.success,
      AppTheme.dashOrange,
    ];

    switch (_salesRange) {
      case 'Weekly':
        return (
          values: [fmtWeekRevenue, fmtWeekProfit, fmtWeekCount],
          colors: colors,
          icons: icons,
          subtitle: 'Last 7 days',
        );
      case 'Monthly':
        return (
          values: [fmtMonthRevenue, fmtMonthProfit, fmtMonthCount],
          colors: colors,
          icons: icons,
          subtitle: 'This month',
        );
      default:
        return (
          values: [fmtTodayRevenue, fmtTodayProfit, fmtTodayCount],
          colors: colors,
          icons: icons,
          subtitle: 'Today',
        );
    }
  }

  ({num revenue, num profit, int salesCount}) _lastWeekTotals() {
    final trend = _summary?['trend'] as List<dynamic>?;
    if (trend == null || trend.length < 7) {
      final m = _summary?['monthly'];
      return (revenue: m?['revenue'] ?? 0, profit: m?['profit'] ?? 0, salesCount: m?['salesCount'] ?? 0);
    }
    num revenue = 0, profit = 0;
    var salesCount = 0;
    for (final t in trend.skip(trend.length - 7)) {
      revenue += (t['revenue'] ?? 0) as num;
      profit += (t['profit'] ?? 0) as num;
      salesCount += (t['salesCount'] ?? 0) as int;
    }
    return (revenue: revenue, profit: profit, salesCount: salesCount);
  }

  Widget _salesActivityCard() {
    final data = _salesActivityData();
    final tiles = <Widget>[];
    for (var i = 0; i < data.values.length; i++) {
      if (i >= _salesMetrics.length || !_salesMetrics[i]) continue;
      tiles.add(SizedBox(
        width: 150,
        child: _statTile(
          const ['Revenue', 'Profit', 'Sales'][i],
          data.values[i],
          data.colors[i],
          data.icons[i],
        ),
      ));
    }

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _cardHeader('Sales Activity',
            action: GestureDetector(
              onTap: _showSalesActivityFilter,
              child: _filterIcon)),
          const SizedBox(height: 4),
          Text(data.subtitle,
            style: TextStyle(
              fontSize: AppTheme.fontSize(context, 11),
              color: AppTheme.secondaryText(context))),
          const SizedBox(height: 12),
          if (tiles.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text('All metrics hidden — use the filter to show some.',
                style: TextStyle(
                  fontSize: AppTheme.fontSize(context, 12),
                  color: AppTheme.secondaryText(context))),
            )
          else
            SizedBox(
              height: 80,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.zero,
                itemCount: tiles.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (_, i) => tiles[i],
              ),
            ),
        ],
      ),
    );
  }

  Widget get _filterIcon => Container(
    width: 34,
    height: 34,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: AppTheme.borderColor(context)),
      color: AppTheme.cardColor(context),
    ),
    child: Icon(Icons.filter_list, size: 18, color: AppTheme.mutedIcon(context)),
  );

  // ---- Quick actions (permission-based) ----

  Widget _quickActionsCard(dynamic auth) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _cardHeader('Quick Actions'),
          const SizedBox(height: 12),
          _panel(
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (auth.user?.hasPermission('view_inventory') == true)
                  _actionCard(context, Icons.inventory, 'Stock', Colors.blue),
                if (auth.user?.hasPermission('record_sales') == true)
                  _actionCard(context, Icons.shopping_cart, 'Sales', Colors.green),
                if (auth.user?.hasPermission('record_damages') == true)
                  _actionCard(context, Icons.warning, 'Damages', Colors.red),
                if (auth.user?.hasPermission('view_reports') == true)
                  _actionCard(context, Icons.bar_chart, 'Reports', Colors.purple),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionCard(BuildContext context, IconData icon, String label, Color color) {
    return Container(
      width: 104,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Icon(icon, size: 24, color: color),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: color)),
        ],
      ),
    );
  }

  // ---- Statistics section (graphs) ----

  List<({String date, num revenue, num profit, int salesCount})> _trendData() {
    final trend = _summary?['trend'] as List<dynamic>?;
    return (trend ?? [])
        .map((t) => (
              date: (t['date'] ?? '') as String,
              revenue: (t['revenue'] ?? 0) as num,
              profit: (t['profit'] ?? 0) as num,
              salesCount: (t['salesCount'] ?? 0) as int,
            ))
        .toList();
  }

  Widget _trendChart(int days) {
    final trend = _trendData();
    if (trend.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text('No sales data for the last 30 days',
            style: TextStyle(
              fontSize: AppTheme.fontSize(context, 13),
              color: AppTheme.secondaryText(context))),
        ),
      );
    }

    final data = trend.length > days ? trend.sublist(trend.length - days) : trend;
    final maxRevenue = data
        .map((e) => e.revenue.toDouble())
        .reduce((a, b) => a > b ? a : b);
    final maxValue = maxRevenue <= 0 ? 1.0 : maxRevenue;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _legendDot(AppTheme.dashNavyColor(context), 'Revenue'),
            const SizedBox(width: 14),
            _legendDot(AppTheme.success, 'Profit'),
            const Spacer(),
            Text('Peak: ${Currency.formatWhole(maxRevenue)}',
              style: TextStyle(
                fontSize: AppTheme.fontSize(context, 11),
                color: AppTheme.secondaryText(context))),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 150,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < data.length; i++)
                Expanded(
                  child: Tooltip(
                    message:
                        '${data[i].date}\nRevenue: ${Currency.formatWhole(data[i].revenue)}\nProfit: ${Currency.formatWhole(data[i].profit)}\nSales: ${data[i].salesCount}',
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: LayoutBuilder(builder: (context, constraints) {
                        final h = constraints.maxHeight;
                        final revenueH = (data[i].revenue / maxValue) * (h - 4);
                        final profitH = (data[i].profit / maxValue) * (h - 4);
                        return Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Container(
                                  width: 5,
                                  height: revenueH < 2 ? 2 : revenueH,
                                  decoration: BoxDecoration(
                                    color: AppTheme.dashNavyColor(context),
                                    borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(3))),
                                ),
                                const SizedBox(width: 2),
                                Container(
                                  width: 5,
                                  height: profitH < 2 ? 2 : profitH,
                                  decoration: BoxDecoration(
                                    color: AppTheme.success,
                                    borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(3))),
                                ),
                              ],
                            ),
                          ],
                        );
                      }),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_shortDay(data.first.date),
              style: TextStyle(
                fontSize: AppTheme.fontSize(context, 10),
                color: AppTheme.secondaryText(context))),
            Text(_shortDay(data.last.date),
              style: TextStyle(
                fontSize: AppTheme.fontSize(context, 10),
                color: AppTheme.secondaryText(context))),
          ],
        ),
      ],
    );
  }

  String _shortDay(String isoDate) {
    final parts = isoDate.split('-');
    if (parts.length < 3) return isoDate;
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final month = months[(int.tryParse(parts[1]) ?? 1) - 1];
    final day = int.parse(parts[2]);
    return '$month $day';
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label,
          style: TextStyle(
            fontSize: AppTheme.fontSize(context, 11),
            color: AppTheme.secondaryText(context))),
      ],
    );
  }

  Widget _statisticsCard() {
    final trend = _trendData();
    final totalRevenue = trend.fold<num>(0, (s, e) => s + e.revenue);
    final totalProfit = trend.fold<num>(0, (s, e) => s + e.profit);
    final totalSales = trend.fold<int>(0, (s, e) => s + e.salesCount);

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _cardHeader('Statistics',
            action: Icon(Icons.insights,
              size: 18, color: AppTheme.mutedIcon(context))),
          const SizedBox(height: 4),
          Text('Last 30 days',
            style: TextStyle(
              fontSize: AppTheme.fontSize(context, 11),
              color: AppTheme.secondaryText(context))),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _statTile('30d Revenue',
                  Currency.formatWhole(totalRevenue),
                  AppTheme.dashNavyColor(context), Icons.payments_outlined)),
              const SizedBox(width: 10),
              Expanded(child: _statTile('30d Profit',
                  Currency.formatWhole(totalProfit),
                  AppTheme.success, Icons.trending_up)),
              const SizedBox(width: 10),
              Expanded(child: _statTile('30d Sales', '$totalSales',
                  AppTheme.dashOrange, Icons.receipt_long_outlined)),
            ],
          ),
          const SizedBox(height: 16),
          Text('Revenue & Profit Trend',
            style: TextStyle(
              fontSize: AppTheme.fontSize(context, 13),
              fontWeight: FontWeight.w600,
              color: AppTheme.textColor(context))),
          const SizedBox(height: 10),
          _trendChart(14),
          const SizedBox(height: 16),
          _panel(child: _topProductsChart()),
          const SizedBox(height: 12),
          _panel(child: _paymentBreakdownChart()),
        ],
      ),
    );
  }

  Widget _topProductsChart() {
    final products = (_summary?['topProducts'] as List<dynamic>? ?? []);
    if (products.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: Text('No product sales in the last 30 days',
            style: TextStyle(
              fontSize: AppTheme.fontSize(context, 12),
              color: AppTheme.secondaryText(context))),
        ),
      );
    }

    final maxRevenue = products
        .map((p) => (p['revenue'] ?? 0) as num)
        .fold<num>(0, (a, b) => a > b ? a : b);
    final maxValue = maxRevenue <= 0 ? 1 : maxRevenue;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Top Selling Products',
          style: TextStyle(
            fontSize: AppTheme.fontSize(context, 13),
            fontWeight: FontWeight.w600,
            color: AppTheme.textColor(context))),
        const SizedBox(height: 10),
        for (var i = 0; i < products.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 90,
                  child: Text('${products[i]['name'] ?? 'Unknown'}',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: AppTheme.fontSize(context, 11),
                      color: AppTheme.secondaryText(context))),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (products[i]['revenue'] ?? 0) / maxValue,
                      minHeight: 10,
                      backgroundColor: AppTheme.dividerColor(context),
                      valueColor: AlwaysStoppedAnimation<Color>(
                          AppTheme.dashNavyColor(context))),
                  ),
                ),
                const SizedBox(width: 8),
                Text(Currency.formatWhole(products[i]['revenue'] ?? 0),
                  style: TextStyle(
                    fontSize: AppTheme.fontSize(context, 11),
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textColor(context))),
              ],
            ),
          ),
      ],
    );
  }

  Widget _paymentBreakdownChart() {
    final breakdown = (_summary?['paymentBreakdown'] as Map<dynamic, dynamic>? ?? {});
    final entries = breakdown.entries
        .map((e) => MapEntry(e.key.toString(), (e.value ?? 0) as num))
        .where((e) => e.value > 0)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold<num>(0, (s, e) => s + e.value);

    final colors = {
      'cash': AppTheme.success,
      'card': AppTheme.blueBright(context),
      'transfer': AppTheme.dashNavyColor(context),
      'credit': AppTheme.warning,
    };
    const icons = {
      'cash': Icons.payments_outlined,
      'card': Icons.credit_card,
      'transfer': Icons.swap_horiz,
      'credit': Icons.receipt_long_outlined,
    };

    if (entries.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: Text('No payment data in the last 30 days',
            style: TextStyle(
              fontSize: AppTheme.fontSize(context, 12),
              color: AppTheme.secondaryText(context))),
        ),
      );
    }

    Widget segment(double fraction, Color color) {
      return Expanded(
        flex: (fraction * 100).round().clamp(1, 100).toInt(),
        child: Container(height: 12, color: color),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Payments (30 days)',
          style: TextStyle(
            fontSize: AppTheme.fontSize(context, 13),
            fontWeight: FontWeight.w600,
            color: AppTheme.textColor(context))),
        const SizedBox(height: 10),
        Row(
          children: [
            for (final e in entries)
              segment(e.value / total, colors[e.key]!),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 14,
          runSpacing: 6,
          children: [
            for (final e in entries)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icons[e.key] ?? Icons.circle_outlined,
                    size: 13, color: colors[e.key]!),
                  const SizedBox(width: 4),
                  Text('${e.key[0].toUpperCase()}${e.key.substring(1)}',
                    style: TextStyle(
                      fontSize: AppTheme.fontSize(context, 11),
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textColor(context))),
                  const SizedBox(width: 4),
                  Text('${(e.value / total * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: AppTheme.fontSize(context, 11),
                      color: AppTheme.secondaryText(context))),
                ],
              ),
          ],
        ),
      ],
    );
  }

  // ---- Welcome card ----

  Widget _welcomeCard(dynamic auth, dynamic branding, {required bool compact}) {
    return _card(
      child: Row(
        children: [
          if (branding?.businessLogo != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(ApiService.fileUrl(branding!.businessLogo),
                height: 40,
                errorBuilder: (_, _, _) => const Icon(Icons.business, size: 40)),
            )
          else
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppTheme.dashNavyColor(context).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.storefront, size: 24, color: AppTheme.dashNavyColor(context)),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(branding?.businessName ?? 'Business',
                  style: TextStyle(
                      fontSize: AppTheme.fontSize(context, 17),
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textColor(context))),
                Text('Welcome back, ${auth.user?.name ?? ''}!',
                  style: TextStyle(
                      color: AppTheme.secondaryText(context),
                      fontSize: AppTheme.fontSize(context, 13))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---- Layouts ----

  Widget _wideLayout(BuildContext context, dynamic auth, dynamic branding) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        _welcomeCard(auth, branding, compact: false),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: _salesActivityCard(),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: _quickActionsCard(auth),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _statisticsCard(),
      ],
    );
  }

  Widget _mobileLayout(BuildContext context, dynamic auth, dynamic branding) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        _welcomeCard(auth, branding, compact: true),
        const SizedBox(height: 12),

        _salesActivityCard(),
        const SizedBox(height: 12),

        // Statistics: graphs (trend chart + top products + payments).
        _statisticsCard(),
        const SizedBox(height: 12),

        // Quick actions in their own horizontally scrollable strip.
        SizedBox(
          height: 130,
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            children: [
              _quickActionsCard(auth),
            ],
          ),
        ),
      ],
    );
  }
}
