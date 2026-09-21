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

  /// Small circular icon button in the card header (like "..."/filter).
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
  Widget _statTile(String label, String value, Color valueColor) {
    return _card(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
            style: TextStyle(
              fontSize: AppTheme.fontSize(context, 11),
              color: AppTheme.secondaryText(context))),
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

  Widget _salesActivityCard(String revenue, String profit, String products, String employees, {required bool twoColumn}) {
    final stats = [
      (revenue, 'Revenue', AppTheme.dashNavyColor(context), Icons.payments_outlined),
      (profit, 'Profit', AppTheme.success, Icons.trending_up),
      (products, 'Stock', AppTheme.dashOrange, Icons.inventory_2_outlined),
      (employees, 'Employees', AppTheme.blueBright(context), Icons.people_outline),
    ];

    final rows = <Widget>[];
    for (var i = 0; i < stats.length; i += twoColumn ? 2 : 4) {
      final take = twoColumn ? 2 : 4;
      final end = (i + take) < stats.length ? (i + take) : stats.length;
      final chunk = stats.sublist(i, end);
      rows.add(
        Row(
          children: [
            for (var j = 0; j < chunk.length; j++) ...[
              if (j > 0) const SizedBox(width: 10),
              Expanded(child: _statTile(chunk[j].$2, chunk[j].$1, chunk[j].$3)),
            ],
            // Keep row heights even when the last row has fewer tiles.
            if (chunk.length < take)
              Expanded(child: const SizedBox()),
          ],
        ),
      );
      rows.add(const SizedBox(height: 10));
    }

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _cardHeader('Sales Activity', action: _headerIcon(Icons.filter_list)),
          const SizedBox(height: 12),
          _panel(
            child: Column(
              children: [
                for (final r in rows)
                  if (r is SizedBox)
                    r
                else
                  r,
              ],
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
              color: AppTheme.secondaryText(context))),
        ),
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
      decoration: isHeader
          ? BoxDecoration(
              color: AppTheme.cardColor(context),
              borderRadius: BorderRadius.circular(10))
          : BoxDecoration(
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
              child: _salesActivityCard(revenue, profit, products, employees, twoColumn: false),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: _inventorySummaryCard(products, lowStock, totalStock),
            ),
          ],
        ),
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
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        _brandingCard(),
        const SizedBox(height: 12),

        _salesActivityCard(revenue, profit, products, employees, twoColumn: true),
        const SizedBox(height: 12),

        _inventorySummaryCard(products, lowStock, totalStock),
        const SizedBox(height: 12),

        _productDetailsCard(d, products, lowStock, totalStock),
        const SizedBox(height: 12),

        _topSellingCard(revenue, mRevenue, mProfit),
        const SizedBox(height: 12),

        _purchaseOrderCard(totalStock, products),
        const SizedBox(height: 12),

        _salesOrderCard(revenue, profit, sales, mRevenue, mProfit),
      ],
    );
  }
}
