import 'package:flutter/material.dart';
import '../../widgets/app_drawer.dart';
import 'admin_dashboard.dart';
import 'store_screen.dart';
import 'products_screen.dart';
import 'categories_screen.dart';
import 'sales_screen.dart';
import 'purchases_screen.dart';
import 'damages_screen.dart';
import 'reports_screen.dart';
import 'employees_screen.dart';
import 'suppliers_screen.dart';

class AdminHome extends StatefulWidget {
  const AdminHome({super.key});
  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  int _currentIndex = 0;

  /// Which branch under the Transactions tree is open.
  /// Index 0 = Sales, index 1 = History, index 2 = Damages.
  int _transactionsChild = 1;
  bool _transactionsExpanded = false;

  /// Which branch under the Company tree is open.
  /// Index 0 = Suppliers, index 1 = Employees.
  int _companyChild = 0;
  bool _companyExpanded = false;

  /// Which branch under the Reports tree is open.
  /// Index 0 = Sales Performance.
  int _reportsChild = 0;
  bool _reportsExpanded = false;

  // Drawer item order:
  // 0 Dashboard | 1 Company | 2 Stock | 3 Categories | 4 Transactions
  // 5 Store | 6 Reports
  static const int _companyIndex = 1;
  static const int _transactionsIndex = 4;
  static const int _reportsIndex = 6;

  DrawerItem _transactionsItem() => DrawerItem(
        icon: Icons.receipt_long_outlined,
        label: 'Transactions',
        builder: _empty,
        children: const [
          DrawerChildItem(icon: Icons.shopping_cart_outlined, label: 'Sales'),
          DrawerChildItem(icon: Icons.history, label: 'History'),
          DrawerChildItem(
              icon: Icons.warning_amber_outlined, label: 'Damages'),
        ],
        activeChildIndex: _transactionsChild,
        initiallyExpanded: _transactionsExpanded,
      );

  DrawerItem _companyItem() => DrawerItem(
        icon: Icons.business_outlined,
        label: 'Company',
        builder: _empty,
        children: const [
          DrawerChildItem(
              icon: Icons.local_shipping_outlined, label: 'Suppliers'),
          DrawerChildItem(icon: Icons.people_outline, label: 'Employees'),
        ],
        activeChildIndex: _companyChild,
        initiallyExpanded: _companyExpanded,
      );

  DrawerItem _reportsItem() => DrawerItem(
        icon: Icons.bar_chart_outlined,
        label: 'Reports',
        builder: _empty,
        children: const [
          DrawerChildItem(icon: Icons.insights, label: 'Sales Performance'),
        ],
        activeChildIndex: _reportsChild,
        initiallyExpanded: _reportsExpanded,
      );

  List<DrawerItem> get _items => [
        const DrawerItem(
            icon: Icons.dashboard_outlined, label: 'Dashboard', builder: _empty),
        _companyItem(),
        const DrawerItem(
            icon: Icons.inventory_2_outlined, label: 'Stock', builder: _empty),
        const DrawerItem(
            icon: Icons.category_outlined, label: 'Categories', builder: _empty),
        _transactionsItem(),
        const DrawerItem(
            icon: Icons.storefront_outlined, label: 'Store', builder: _empty),
        _reportsItem(),
      ];

  static Widget _empty() => const SizedBox();

  /// "View All" links on the dashboard: 0 opens Sales, 1 opens Stock.
  void _openFromDashboard(int target) {
    onItemTapLocal(target == 0 ? _transactionsIndex : 2,
        childIndex: target == 0 ? 0 : null);
  }

  /// Page stack order matches the drawer:
  /// 0 Dashboard | 1 Suppliers | 2 Employees | 3 Stock | 4 Categories
  /// 5 Sales | 6 History | 7 Damages | 8 Store | 9 Reports
  late final List<Widget> _pages = [
    AdminDashboard(onSeeAll: _openFromDashboard),
    SuppliersScreen(),
    EmployeesScreen(),
    ProductsScreen(),
    CategoriesScreen(),
    SalesScreen(),
    PurchasesScreen(),
    DamagesScreen(),
    StoreScreen(),
    ReportsScreen(),
  ];

  /// Maps the selected drawer item to the [IndexedStack] page index.
  /// Tree parents (Company, Transactions) resolve through their active
  /// child branch; leaf items map straight across.
  int get _stackIndex {
    switch (_currentIndex) {
      case 0:
        return 0; // Dashboard
      case _companyIndex:
        return _companyChild == 0 ? 1 : 2; // Suppliers / Employees
      case 2:
        return 3; // Stock
      case 3:
        return 4; // Categories
      case _transactionsIndex:
        return _transactionsChild == 0
            ? 5
            : _transactionsChild == 1
                ? 6 // History
                : 7; // Damages
      case 5:
        return 8; // Store
      case _reportsIndex:
        return 9; // Reports (Sales Performance)
      default:
        return 0;
    }
  }

  /// Central navigation logic, shared by the nav wrapper and the
  /// dashboard's "View All" links.
  void onItemTapLocal(int i, {int? childIndex}) {
    setState(() {
      if (i == _transactionsIndex) {
        // Tapping the parent toggles the branch; a child tap opens it.
        if (childIndex != null) {
          _transactionsChild = childIndex;
          _transactionsExpanded = true;
          _currentIndex = i;
        } else {
          _transactionsExpanded = !_transactionsExpanded;
        }
      } else if (i == _companyIndex) {
        if (childIndex != null) {
          _companyChild = childIndex;
          _companyExpanded = true;
          _currentIndex = i;
        } else {
          _companyExpanded = !_companyExpanded;
        }
      } else if (i == _reportsIndex) {
        if (childIndex != null) {
          _reportsChild = childIndex;
          _reportsExpanded = true;
          _currentIndex = i;
        } else {
          _reportsExpanded = !_reportsExpanded;
        }
      } else {
        _currentIndex = i;
        _transactionsExpanded = false;
        _companyExpanded = false;
        _reportsExpanded = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // The Employees screen (Company > Employees) hosts its own FAB that
    // already includes the theme toggle.
    final isEmployeesTab = _currentIndex == _companyIndex && _companyChild == 1;

    return ResponsiveNavWrapper(
      selectedIndex: _currentIndex,
      onItemTap: onItemTapLocal,
      items: _items,
      title: 'Business Dashboard',
      showThemeFab: !isEmployeesTab,
      body: IndexedStack(
        index: _stackIndex,
        children: _pages,
      ),
    );
  }
}
