import 'package:flutter/material.dart';
import '../../widgets/app_drawer.dart';
import 'admin_dashboard.dart';
import 'store_screen.dart';
import 'products_screen.dart';
import 'categories_screen.dart';
import 'sales_screen.dart';
import 'purchases_screen.dart';
import 'expenses_screen.dart';
import 'credits_screen.dart';
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
  /// Index 0 = Sales, index 1 = Expenses, index 2 = Credits,
  /// index 3 = History, index 4 = Damages.
  int _transactionsChild = 3;
  bool _transactionsExpanded = false;

  /// Which branch under the Company tree is open.
  /// Index 0 = Suppliers, index 1 = Employees.
  int _companyChild = 0;
  bool _companyExpanded = false;

  /// Which branch under Categories is open.
  /// Index 0 = Product, index 1 = Expense.
  int _categoriesChild = 0;
  bool _categoriesExpanded = false;

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
      DrawerChildItem(icon: Icons.payments_outlined, label: 'Expenses'),
      DrawerChildItem(icon: Icons.credit_card_outlined, label: 'Credits'),
      DrawerChildItem(icon: Icons.history, label: 'History'),
      DrawerChildItem(icon: Icons.warning_amber_outlined, label: 'Damages'),
    ],
    activeChildIndex: _transactionsChild,
    initiallyExpanded: _transactionsExpanded,
  );

  DrawerItem _companyItem() => DrawerItem(
    icon: Icons.business_outlined,
    label: 'Company',
    builder: _empty,
    children: const [
      DrawerChildItem(icon: Icons.local_shipping_outlined, label: 'Suppliers'),
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

  DrawerItem _categoriesItem() => DrawerItem(
    icon: Icons.category_outlined,
    label: 'Categories',
    builder: _empty,
    children: const [
      DrawerChildItem(icon: Icons.inventory_2_outlined, label: 'Product'),
      DrawerChildItem(icon: Icons.payments_outlined, label: 'Expense'),
    ],
    activeChildIndex: _categoriesChild,
    initiallyExpanded: _categoriesExpanded,
  );

  List<DrawerItem> get _items => [
    const DrawerItem(
      icon: Icons.dashboard_outlined,
      label: 'Dashboard',
      builder: _empty,
    ),
    _companyItem(),
    const DrawerItem(
      icon: Icons.inventory_2_outlined,
      label: 'Stock',
      builder: _empty,
    ),
    _categoriesItem(),
    _transactionsItem(),
    const DrawerItem(
      icon: Icons.storefront_outlined,
      label: 'Store',
      builder: _empty,
    ),
    _reportsItem(),
  ];

  static Widget _empty() => const SizedBox();

  /// "View All" links on the dashboard: 0 opens Sales, 1 opens Stock.
  void _openFromDashboard(int target) {
    onItemTapLocal(
      target == 0 ? _transactionsIndex : 2,
      childIndex: target == 0 ? 0 : null,
    );
  }

  /// Page stack order matches the drawer:
  /// 0 Dashboard | 1 Suppliers | 2 Employees | 3 Stock
  /// 4 Product Categories | 5 Expense Categories | 6 Sales
  /// 7 Expenses | 8 Credits | 9 History | 10 Damages | 11 Store | 12 Reports
  late final List<Widget> _pages = [
    AdminDashboard(onSeeAll: _openFromDashboard),
    SuppliersScreen(),
    EmployeesScreen(),
    ProductsScreen(),
    CategoriesScreen(categoryType: 'product'),
    CategoriesScreen(categoryType: 'expense'),
    SalesScreen(),
    ExpensesScreen(),
    CreditsScreen(),
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
        return _categoriesChild == 0
            ? 4 // Product Categories
            : 5; // Expense Categories
      case _transactionsIndex:
        return _transactionsChild == 0
            ? 6
            : _transactionsChild == 1
            ? 7 // Expenses
            : _transactionsChild == 2
            ? 8 // Credits
            : _transactionsChild == 3
            ? 9 // History
            : 10; // Damages
      case 5:
        return 11; // Store
      case _reportsIndex:
        return 12; // Reports (Sales Performance)
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
      } else if (i == 3) {
        if (childIndex != null) {
          _categoriesChild = childIndex;
          _categoriesExpanded = true;
          _currentIndex = i;
        } else {
          _categoriesExpanded = !_categoriesExpanded;
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
        _categoriesExpanded = false;
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
      body: IndexedStack(index: _stackIndex, children: _pages),
    );
  }
}
