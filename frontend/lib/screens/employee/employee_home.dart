import 'package:flutter/material.dart';
import '../../widgets/app_drawer.dart';
import 'employee_dashboard.dart';
import '../admin/products_screen.dart';
import '../admin/categories_screen.dart';
import '../admin/sales_screen.dart';
import '../admin/purchases_screen.dart';
import '../admin/damages_screen.dart';
import '../admin/reports_screen.dart';

class EmployeeHome extends StatefulWidget {
  const EmployeeHome({super.key});
  @override
  State<EmployeeHome> createState() => _EmployeeHomeState();
}

class _EmployeeHomeState extends State<EmployeeHome> {
  int _currentIndex = 0;

  final _items = const [
    DrawerItem(icon: Icons.dashboard_outlined, label: 'Dashboard', builder: _empty),
    DrawerItem(icon: Icons.inventory_2_outlined, label: 'Products', builder: _empty),
    DrawerItem(icon: Icons.category_outlined, label: 'Categories', builder: _empty),
    DrawerItem(icon: Icons.shopping_cart_outlined, label: 'Sales', builder: _empty),
    DrawerItem(icon: Icons.local_shipping_outlined, label: 'Purchases', builder: _empty),
    DrawerItem(icon: Icons.warning_amber_outlined, label: 'Damages', builder: _empty),
    DrawerItem(icon: Icons.bar_chart_outlined, label: 'Reports', builder: _empty),
  ];

  static Widget _empty() => const SizedBox();

  late final List<Widget> _pages = const [
    EmployeeDashboard(),
    ProductsScreen(),
    CategoriesScreen(),
    SalesScreen(),
    PurchasesScreen(),
    DamagesScreen(),
    ReportsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return ResponsiveNavWrapper(
      selectedIndex: _currentIndex,
      onItemTap: (i) => setState(() => _currentIndex = i),
      items: _items,
      title: 'Employee Dashboard',
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
    );
  }
}
