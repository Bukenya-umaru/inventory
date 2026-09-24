import 'package:flutter/material.dart';
import '../../widgets/app_drawer.dart';
import 'employee_dashboard.dart';
import '../admin/store_screen.dart';
import '../admin/products_screen.dart';
import '../admin/categories_screen.dart';
import '../admin/sales_screen.dart';
import '../admin/purchases_screen.dart';
import '../admin/damages_screen.dart';
import '../admin/reports_screen.dart';
import '../admin/suppliers_screen.dart';

class EmployeeHome extends StatefulWidget {
  const EmployeeHome({super.key});
  @override
  State<EmployeeHome> createState() => _EmployeeHomeState();
}

class _EmployeeHomeState extends State<EmployeeHome> {
  int _currentIndex = 0;

  /// Which branch under the Transactions tree is open.
  /// Index 0 = Sales, index 1 = History, index 2 = Damages.
  int _transactionsChild = 1;
  bool _transactionsExpanded = false;

  /// Which branch under the Company tree is open.
  /// Index 0 = Suppliers. (Employees is admin-only.)
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

  /// Page stack order matches the drawer:
  /// 0 Dashboard | 1 Suppliers | 2 Stock | 3 Categories
  /// 4 Sales | 5 History | 6 Damages | 7 Store | 8 Reports
  late final List<Widget> _pages = const [
    EmployeeDashboard(),
    SuppliersScreen(),
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
        return 1; // Suppliers (Employees is admin-only)
      case 2:
        return 2; // Stock
      case 3:
        return 3; // Categories
      case _transactionsIndex:
        return _transactionsChild == 0
            ? 4
            : _transactionsChild == 1
                ? 5 // History
                : 6; // Damages
      case 5:
        return 7; // Store
      case _reportsIndex:
        return 8; // Reports (Sales Performance)
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveNavWrapper(
      selectedIndex: _currentIndex,
      onItemTap: (i, {int? childIndex}) {
        setState(() {
          if (i == _transactionsIndex) {
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
      },
      items: _items,
      title: 'Employee Dashboard',
      body: IndexedStack(
        index: _stackIndex,
        children: _pages,
      ),
    );
  }
}
