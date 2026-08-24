import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
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
  void initState() { super.initState(); _load(); }

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

  // ── Wide / Laptop Layout ──
  Widget _wideLayout(dynamic d, String revenue, String profit, String products, String employees, String mRevenue, String mProfit, String sales, String lowStock, String totalStock) {
    final productCount = products;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // Row 1: Sales Activity + Inventory Summary
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sales Activity (left)
            Expanded(
              flex: 3,
              child: _sectionCard(
                title: 'Sales Activity',
                child: Row(
                  children: [
                    _activityStat(revenue, 'Revenue', AppTheme.primary, Icons.monetization_on),
                    _activityStat(profit, 'Profit', AppTheme.success, Icons.trending_up),
                    _activityStat(products, 'Products', Colors.purple, Icons.inventory_2),
                    _activityStat(employees, 'Employees', Colors.orange, Icons.people),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Inventory Summary (right)
            Expanded(
              flex: 2,
              child: _sectionCard(
                title: 'Inventory Summary',
                child: Column(
                  children: [
                    _summaryRow('Quantity in Hand', productCount, Icons.inventory),
                    const Divider(height: 1),
                    _summaryRow('Quantity to Receive', lowStock, Icons.receipt_long),
                    const Divider(height: 1),
                    _summaryRow('Total Stock Value', totalStock, Icons.monetization_on),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Row 2: Product Details + Top Selling Items
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Details (left)
            Expanded(
              flex: 3,
              child: _sectionCard(
                title: 'Product Details',
                child: Column(
                  children: [
                    _detailRow('Low Stock Items', lowStock, isWarning: true),
                    _detailRow('All Item Groups', '${d['categoryCount'] ?? 0}', isWarning: false),
                    _detailRow('All Items', productCount, isWarning: false),
                    _detailRow('Total Stock Value', totalStock, isWarning: false),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Top Selling (right)
            Expanded(
              flex: 2,
              child: _sectionCard(
                title: 'Top Selling Items',
                child: Column(
                  children: [
                    _sellingItem('Today\'s Sales', revenue, AppTheme.primary, Icons.trending_up),
                    _sellingItem('This Month', mRevenue, AppTheme.success, Icons.calendar_month),
                    _sellingItem('Profit', mProfit, Colors.purple, Icons.monetization_on),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Row 3: Purchase Order + Sales Order
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Purchase Order
            Expanded(
              flex: 2,
              child: _sectionCard(
                title: 'Purchase Order',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(totalStock, style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppTheme.primary)),
                    const SizedBox(height: 4),
                    Text('Stock Value', style: TextStyle(fontSize: 14, color: AppTheme.secondaryText(context))),
                    const SizedBox(height: 16),
                    _miniStat('Quantity Ordered', products, Icons.shopping_cart),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Sales Order
            Expanded(
              flex: 3,
              child: _sectionCard(
                title: 'Sales Order',
                child: Column(
                  children: [
                    _orderRow(['Channel', 'Revenue', 'Profit', 'Sales'], isHeader: true),
                    _orderRow(['Today', revenue, profit, sales]),
                    _orderRow(['Monthly', mRevenue, mProfit, sales]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Mobile / Narrow Layout ──
  Widget _mobileLayout(dynamic d, String revenue, String profit, String products, String employees, String mRevenue, String mProfit, String sales, String lowStock, String totalStock) {
    final productCount = products;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Sales Activity
        _sectionCard(
          title: 'Sales Activity',
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: _activityStat(revenue, 'Revenue', AppTheme.primary, Icons.monetization_on)),
                  Expanded(child: _activityStat(profit, 'Profit', AppTheme.success, Icons.trending_up)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _activityStat(products, 'Products', Colors.purple, Icons.inventory_2)),
                  Expanded(child: _activityStat(employees, 'Employees', Colors.orange, Icons.people)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Inventory Summary
        _sectionCard(
          title: 'Inventory Summary',
          child: Column(
            children: [
              _summaryRow('Quantity in Hand', productCount, Icons.inventory),
              const Divider(height: 1),
              _summaryRow('Quantity to Receive', lowStock, Icons.receipt_long),
              const Divider(height: 1),
              _summaryRow('Total Stock Value', totalStock, Icons.monetization_on),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Product Details
        _sectionCard(
          title: 'Product Details',
          child: Column(
            children: [
              _detailRow('Low Stock Items', lowStock, isWarning: true),
              _detailRow('All Item Groups', '${d['categoryCount'] ?? 0}', isWarning: false),
              _detailRow('All Items', products, isWarning: false),
              _detailRow('Total Stock Value', totalStock, isWarning: false),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Top Selling
        _sectionCard(
          title: 'Top Selling Items',
          child: Column(
            children: [
              _sellingItem('Today\'s Sales', revenue, AppTheme.primary, Icons.trending_up),
              _sellingItem('This Month', mRevenue, AppTheme.success, Icons.calendar_month),
              _sellingItem('Profit', mProfit, Colors.purple, Icons.monetization_on),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Purchase Order
        _sectionCard(
          title: 'Purchase Order',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(totalStock, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.primary)),
              const SizedBox(height: 4),            Text('Stock Value', style: TextStyle(fontSize: 14, color: AppTheme.secondaryText(context))),
                    const SizedBox(height: 12),
                    _miniStat('Quantity Ordered', products, Icons.shopping_cart),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Sales Order
        _sectionCard(
          title: 'Sales Order',
          child: Column(
            children: [
              _orderRow(['Channel', 'Revenue', 'Profit', 'Sales'], isHeader: true),
              _orderRow(['Today', revenue, profit, sales]),
              _orderRow(['Monthly', mRevenue, mProfit, sales]),
            ],
          ),
        ),
      ],
    );
  }

  // ── Shared Widgets ──

  Widget _sectionCard({required String title, required Widget child}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textColor(context))),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  Widget _activityStat(String value, String label, Color color, IconData icon) {
    return Container(
      margin: const EdgeInsets.all(4),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 11, color: AppTheme.secondaryText(context))),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: TextStyle(fontSize: 14, color: AppTheme.secondaryText(context)))),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textColor(context))),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value, {required bool isWarning}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(fontSize: 14, color: isWarning ? AppTheme.warning : AppTheme.secondaryText(context)))),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isWarning ? AppTheme.warning : AppTheme.textColor(context))),
        ],
      ),
    );
  }

  Widget _sellingItem(String label, String value, Color color, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: TextStyle(fontSize: 14, color: AppTheme.secondaryText(context)))),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value, IconData icon) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 16, color: AppTheme.secondaryText(context)),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 13, color: AppTheme.secondaryText(context))),
        const SizedBox(width: 8),
        Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _orderRow(List<String> cells, {bool isHeader = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: isHeader
          ? BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(4))
          : null,
      child: Row(
        children: cells.map((c) => Expanded(
          child: Text(c,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isHeader ? FontWeight.w600 : FontWeight.w400,
              color: isHeader ? AppTheme.secondaryText(context) : AppTheme.textColor(context),
            ),
          ),
        )).toList(),
      ),
    );
  }
}
