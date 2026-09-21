import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../services/app_events.dart';
import '../../services/auth_provider.dart';
import '../../utils/theme.dart';
import '../../utils/currency.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});
  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String _salesRange = 'Today'; // Sales Activity filter: Today | Weekly | Monthly
  List<bool> _salesMetrics = [true, true, true, true]; // Revenue, Profit, Stock, Employees

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
    final size = MediaQuery.of(context).size;
    final isWide = size.width >= 900;

    if (_loading) return const Center(child: CircularProgressIndicator());
    final d = _data ?? {};

    final todayRevenue = Currency.formatWhole((d['today']?['revenue'] ?? 0));
    final todayProfit = Currency.formatWhole((d['today']?['profit'] ?? 0));
    final productCount = '${d['productCount'] ?? 0}';
    final employeeCount = '${d['employeeCount'] ?? 0}';
    final monthlyRevenue = Currency.formatWhole((d['monthly']?['revenue'] ?? 0));
    final monthlyProfit = Currency.formatWhole((d['monthly']?['profit'] ?? 0));
    final salesCount = '${d['monthly']?['salesCount'] ?? 0}';
    final lowStock = '${d['lowStockCount'] ?? 0}';
    final totalStock = Currency.formatWhole(d['totalStockValue'] ?? 0);

    return RefreshIndicator(
      onRefresh: _load,
      child: isWide
          ? _wideLayout(d, todayRevenue, todayProfit, productCount, employeeCount, monthlyRevenue, monthlyProfit, salesCount, lowStock, totalStock)
          : _mobileLayout(d, todayRevenue, todayProfit, productCount, employeeCount, monthlyRevenue, monthlyProfit, salesCount, lowStock, totalStock),
    );
  }

  // ---- Design-system building blocks (dashboard mock style) ----

  /// White rounded card used as outer container.
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

  /// Card header: title on the left, optional action on the right.
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

  /// Inner light-gray panel that holds white sub-cards (mock style).
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

  /// Small circular icon button in the card header (like "..." / filter).
  Widget _headerIcon(IconData icon) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.borderColor(context)),
        color: AppTheme.cardColor(context),
      ),
      child: Icon(icon, size: 18, color: AppTheme.mutedIcon(context)),
    );
  }

  /// Muted label + bold value, the mock's stat style.
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

  // ---- Sections ----

  Widget _brandingCard() {
    final auth = context.watch<AuthProvider>();
    final branding = auth.branding;
    return _card(
      child: Row(
        children: [
          if (branding?.businessLogo != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(ApiService.fileUrl(branding!.businessLogo),
                height: 40,
                errorBuilder: (_, _, _) => Icon(Icons.storefront,
                    size: 40, color: AppTheme.dashNavyColor(context))),
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

  /// Sales Activity filter bottom sheet.
  Future<void> _showSalesActivityFilter() async {
    var range = _salesRange;
    var metrics = List<bool>.from(_salesMetrics);
    const labels = ['Revenue', 'Profit', 'Stock', 'Employees'];

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
                      ChoiceChip(
                        label: Text(r),
                        selected: range == r,
                        selectedColor:
                            AppTheme.dashNavyColor(sheetContext).withValues(alpha: 0.15),
                        labelStyle: TextStyle(
                          color: range == r
                              ? AppTheme.dashNavyColor(sheetContext)
                              : AppTheme.secondaryText(sheetContext),
                          fontWeight: range == r ? FontWeight.bold : FontWeight.w500),
                        onSelected: (_) => setSheetState(() => range = r),
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
                ...List.generate(4, (i) => CheckboxListTile(
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
                          metrics = [true, true, true, true];
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

  /// Values for the Sales Activity tiles according to the current filter.
  ({List<String> values, String subtitle}) _salesActivityValues(
    String revenue, String profit, String products, String employees,
    String mRevenue, String mProfit, String sales,
  ) {
    switch (_salesRange) {
      case 'Weekly':
        final week = _lastWeekTotals();
        return (
          values: [
            Currency.formatWhole(week.revenue),
            Currency.formatWhole(week.profit),
            products,
            employees,
          ],
          subtitle: 'Last 7 days · ${week.salesCount} sales',
        );
      case 'Monthly':
        return (
          values: [mRevenue, mProfit, products, employees],
          subtitle: 'This month · $sales sales',
        );
      default:
        return (
          values: [revenue, profit, products, employees],
          subtitle: 'Today · ${_todaySalesCount()} sales',
        );
    }
  }

  ({num revenue, num profit, int salesCount}) _lastWeekTotals() {
    final trend = _data?['trend'] as List<dynamic>?;
    if (trend == null || trend.length < 7) {
      final m = _data?['monthly'];
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

  int _todaySalesCount() {
    final trend = _data?['trend'] as List<dynamic>?;
    if (trend != null && trend.isNotEmpty) {
      return (trend.last['salesCount'] ?? 0) as int;
    }
    return (_data?['today']?['salesCount'] ?? 0) as int;
  }

  Widget _salesActivityCard(String revenue, String profit, String products, String employees,
      {required bool twoColumn, String mRevenue = '', String mProfit = '', String sales = '0'}) {
    final allIcons = [
      Icons.payments_outlined,
      Icons.trending_up,
      Icons.inventory_2_outlined,
      Icons.people_outline,
    ];
    final data = _salesActivityValues(revenue, profit, products, employees, mRevenue, mProfit, sales);
    final visible = <int>[];
    for (var i = 0; i < _salesMetrics.length; i++) {
      if (_salesMetrics[i]) visible.add(i);
    }

    final tiles = <Widget>[];
    for (final i in visible) {
      final colors = [
        AppTheme.dashNavyColor(context),
        AppTheme.success,
        AppTheme.dashOrange,
        AppTheme.blueBright(context),
      ];
      tiles.add(SizedBox(
        width: twoColumn ? 160 : 150,
        child: _statTile(
          const ['Revenue', 'Profit', 'Stock', 'Employees'][i],
          data.values[i],
          colors[i],
          allIcons[i],
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
              child: _headerIcon(Icons.filter_list))),
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
              height: twoColumn ? 84 : 80,
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

  Widget _inventorySummaryCard(String productCount, String lowStock, String totalStock) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _cardHeader('Inventory Summary', action: _headerIcon(Icons.more_horiz)),
          const SizedBox(height: 12),
          _panel(
            child: Column(
              children: [
                _summaryRow('Quantity in Hand', productCount, Icons.inventory_2_outlined),
                Divider(height: 1, color: AppTheme.dividerColor(context)),
                _summaryRow('Quantity to Receive', lowStock, Icons.receipt_long_outlined),
                Divider(height: 1, color: AppTheme.dividerColor(context)),
                _summaryRow('Total Stock Value', totalStock, Icons.payments_outlined),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _productDetailsCard(dynamic d, String productCount, String lowStock, String totalStock) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _cardHeader('Product Details', action: _headerIcon(Icons.more_horiz)),
          const SizedBox(height: 12),
          _panel(
            child: Column(
              children: [
                _detailChipRow('Low Stock Items', lowStock, warning: true),
                const SizedBox(height: 8),
                _detailChipRow('All Item Groups', '${d['categoryCount'] ?? 0}', warning: false),
                const SizedBox(height: 8),
                _detailChipRow('All Items', productCount, warning: false),
                const SizedBox(height: 8),
                _detailChipRow('Total Stock Value', totalStock, warning: false),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _topSellingCard(String revenue, String mRevenue, String mProfit) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _cardHeader('Top Selling Items', action: _headerIcon(Icons.more_horiz)),
          const SizedBox(height: 12),
          _panel(
            child: Column(
              children: [
                _sellingItem('Today\'s Sales', revenue, AppTheme.success, Icons.trending_up),
                const SizedBox(height: 8),
                _sellingItem('This Month', mRevenue, AppTheme.blueBright(context), Icons.calendar_month_outlined),
                const SizedBox(height: 8),
                _sellingItem('Profit', mProfit, AppTheme.dashOrange, Icons.payments_outlined),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _purchaseOrderCard(String totalStock, String productCount) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _cardHeader('Purchase Order', action: _headerIcon(Icons.more_horiz)),
          const SizedBox(height: 12),
          _panel(
            child: Column(
              children: [
                const SizedBox(height: 8),
                Center(
                  child: Text(totalStock,
                    style: TextStyle(
                      fontSize: AppTheme.fontSize(context, 30),
                      fontWeight: FontWeight.bold,
                      color: AppTheme.dashNavyColor(context))),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text('Stock Value',
                    style: TextStyle(
                      fontSize: AppTheme.fontSize(context, 13),
                      color: AppTheme.secondaryText(context))),
                ),
                const SizedBox(height: 12),
                _card(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.shopping_cart_outlined,
                        size: 16, color: AppTheme.secondaryText(context)),
                      const SizedBox(width: 6),
                      Text('Quantity Ordered',
                        style: TextStyle(
                          fontSize: AppTheme.fontSize(context, 12),
                          color: AppTheme.secondaryText(context))),
                      const SizedBox(width: 8),
                      Text(productCount,
                        style: TextStyle(
                          fontSize: AppTheme.fontSize(context, 15),
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textColor(context))),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _salesOrderCard(String revenue, String profit, String sales, String mRevenue, String mProfit) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _cardHeader('Sales Order', action: _headerIcon(Icons.more_horiz)),
          const SizedBox(height: 12),
          _panel(
            child: Column(
              children: [
                _orderRow(['Channel', 'Revenue', 'Profit', 'Sales'], isHeader: true),
                const SizedBox(height: 6),
                _orderRow(['Today', revenue, profit, sales]),
                const SizedBox(height: 6),
                _orderRow(['Monthly', mRevenue, mProfit, sales]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---- Statistics section ----

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

  /// Custom bar chart (no chart library): one bar per day, last 7/14/30 days.
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
            action: _headerIcon(Icons.insights)),
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
    final products = (_data?['topProducts'] as List<dynamic>? ?? []);
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
    final breakdown = (_data?['paymentBreakdown'] as Map<dynamic, dynamic>? ?? {});
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

  // ---- Rows ----

  Widget _summaryRow(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.dashNavyColor(context)),
          const SizedBox(width: 10),
          Expanded(child: Text(label,
            style: TextStyle(
              fontSize: AppTheme.fontSize(context, 13),
              color: AppTheme.secondaryText(context)))),
          Text(value,
            style: TextStyle(
              fontSize: AppTheme.fontSize(context, 15),
              fontWeight: FontWeight.bold,
              color: AppTheme.textColor(context))),
        ],
      ),
    );
  }

  Widget _detailChipRow(String label, String value, {required bool warning}) {
    final color = warning ? AppTheme.warning : AppTheme.dashNavyColor(context);
    return Row(
      children: [
        Expanded(
          child: Text(label,
            style: TextStyle(
              fontSize: AppTheme.fontSize(context, 13),
              color: AppTheme.secondaryText(context)))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Text(value,
            style: TextStyle(
              fontSize: AppTheme.fontSize(context, 13),
              fontWeight: FontWeight.w600,
              color: color)),
        ),
      ],
    );
  }

  Widget _sellingItem(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(label,
            style: TextStyle(
              fontSize: AppTheme.fontSize(context, 13),
              color: AppTheme.secondaryText(context)))),
          Text(value,
            style: TextStyle(
              fontSize: AppTheme.fontSize(context, 15),
              fontWeight: FontWeight.bold,
              color: color)),
        ],
      ),
    );
  }

  Widget _orderRow(List<String> cells, {bool isHeader = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: cells.asMap().entries.map((e) => Expanded(
          flex: e.key == 0 ? 2 : 1,
          child: Text(e.value,
            style: TextStyle(
              fontSize: AppTheme.fontSize(context, 12),
              fontWeight: isHeader ? FontWeight.w600 : FontWeight.w500,
              color: isHeader
                  ? AppTheme.secondaryText(context)
                  : AppTheme.textColor(context),
            ),
          ),
        )).toList(),
      ),
    );
  }

  // ---- Layouts ----

  Widget _wideLayout(dynamic d, String revenue, String profit, String products, String employees, String mRevenue, String mProfit, String sales, String lowStock, String totalStock) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        _brandingCard(),
        const SizedBox(height: 16),

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: _salesActivityCard(revenue, profit, products, employees,
                  twoColumn: false, mRevenue: mRevenue, mProfit: mProfit, sales: sales),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: _inventorySummaryCard(products, lowStock, totalStock),
            ),
          ],
        ),
        const SizedBox(height: 16),

        _statisticsCard(),
        const SizedBox(height: 16),

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: _productDetailsCard(d, products, lowStock, totalStock),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: _topSellingCard(revenue, mRevenue, mProfit),
            ),
          ],
        ),
        const SizedBox(height: 16),

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: _purchaseOrderCard(totalStock, products),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 3,
              child: _salesOrderCard(revenue, profit, sales, mRevenue, mProfit),
            ),
          ],
        ),
      ],
    );
  }

  Widget _mobileLayout(dynamic d, String revenue, String profit, String products, String employees, String mRevenue, String mProfit, String sales, String lowStock, String totalStock) {
    final otherCards = <Widget>[
      _inventorySummaryCard(products, lowStock, totalStock),
      _productDetailsCard(d, products, lowStock, totalStock),
      _topSellingCard(revenue, mRevenue, mProfit),
      _purchaseOrderCard(totalStock, products),
      _salesOrderCard(revenue, profit, sales, mRevenue, mProfit),
    ];

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        _brandingCard(),
        const SizedBox(height: 12),

        _salesActivityCard(revenue, profit, products, employees,
            twoColumn: true, mRevenue: mRevenue, mProfit: mProfit, sales: sales),
        const SizedBox(height: 12),

        // Statistics: graphs (trend chart + top products + payments).
        _statisticsCard(),
        const SizedBox(height: 12),

        // All other sections side-by-side in one horizontally scrollable strip.
        SizedBox(
          height: 380,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: otherCards.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (_, i) => SizedBox(width: 280, child: otherCards[i]),
          ),
        ),
      ],
    );
  }
}
