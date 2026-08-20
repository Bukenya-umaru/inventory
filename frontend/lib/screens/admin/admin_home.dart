import 'package:flutter/material.dart';
import '../../widgets/app_drawer.dart';
import 'admin_dashboard.dart';
import 'products_screen.dart';
import 'categories_screen.dart';
import 'sales_screen.dart';
import 'damages_screen.dart';
import 'reports_screen.dart';
import 'employees_screen.dart';

class AdminHome extends StatefulWidget {
  const AdminHome({super.key});
  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  int _currentIndex = 0;

  final _items = const [
    DrawerItem(icon: Icons.dashboard_outlined, label: 'Dashboard', builder: _empty),
    DrawerItem(icon: Icons.inventory_2_outlined, label: 'Products', builder: _empty),
    DrawerItem(icon: Icons.category_outlined, label: 'Categories', builder: _empty),
    DrawerItem(icon: Icons.shopping_cart_outlined, label: 'Sales', builder: _empty),
    DrawerItem(icon: Icons.warning_amber_outlined, label: 'Damages', builder: _empty),
    DrawerItem(icon: Icons.bar_chart_outlined, label: 'Reports', builder: _empty),
    DrawerItem(icon: Icons.people_outline, label: 'Employees', builder: _empty),
  ];

  static Widget _empty() => const SizedBox();

  Widget _buildPage(int index) {
    switch (index) {
      case 0: return const AdminDashboard();
      case 1: return const ProductsScreen();
      case 2: return const CategoriesScreen();
      case 3: return const SalesScreen();
      case 4: return const DamagesScreen();
      case 5: return const ReportsScreen();
      case 6: return const EmployeesScreen();
      default: return const AdminDashboard();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveNavWrapper(
      selectedIndex: _currentIndex,
      onItemTap: (i) => setState(() => _currentIndex = i),
      items: _items,
      title: 'Business Dashboard',
      body: _buildPage(_currentIndex),
    );
  }
}
