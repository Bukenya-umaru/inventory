import 'package:flutter/material.dart';
import '../../widgets/app_drawer.dart';
import 'employee_dashboard.dart';
import '../admin/products_screen.dart';
import '../admin/categories_screen.dart';
import '../admin/sales_screen.dart';
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
    DrawerItem(icon: Icons.warning_amber_outlined, label: 'Damages', builder: _empty),
    DrawerItem(icon: Icons.bar_chart_outlined, label: 'Reports', builder: _empty),
  ];

  static Widget _empty() => const SizedBox();

  Widget _buildPage(int index) {
    switch (index) {
      case 0: return const EmployeeDashboard();
      case 1: return const ProductsScreen();
      case 2: return const CategoriesScreen();
      case 3: return const SalesScreen();
      case 4: return const DamagesScreen();
      case 5: return const ReportsScreen();
      default: return const EmployeeDashboard();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveNavWrapper(
      selectedIndex: _currentIndex,
      onItemTap: (i) => setState(() => _currentIndex = i),
      items: _items,
      title: 'Employee Dashboard',
      body: _buildPage(_currentIndex),
    );
  }
}
