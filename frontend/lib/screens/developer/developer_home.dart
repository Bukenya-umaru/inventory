import 'package:flutter/material.dart';
import '../../widgets/app_drawer.dart';
import 'developer_dashboard.dart';
import 'businesses_screen.dart';
import 'users_screen.dart';
import 'password_manager_screen.dart';
import 'audit_logs_screen.dart';

class DeveloperHome extends StatefulWidget {
  const DeveloperHome({super.key});
  @override
  State<DeveloperHome> createState() => _DeveloperHomeState();
}

class _DeveloperHomeState extends State<DeveloperHome> {
  int _currentIndex = 0;

  final _items = const [
    DrawerItem(icon: Icons.dashboard_outlined, label: 'Dashboard', builder: _empty),
    DrawerItem(icon: Icons.business_center, label: 'Businesses', builder: _empty),
    DrawerItem(icon: Icons.people_outline, label: 'All Users', builder: _empty),
    DrawerItem(icon: Icons.key, label: 'Password Manager', builder: _empty),
    DrawerItem(icon: Icons.shield_outlined, label: 'Audit Logs', builder: _empty),
  ];

  static Widget _empty() => const SizedBox();

  late final List<Widget> _pages = [
    DeveloperDashboard(onNavigateToTab: (i) => setState(() => _currentIndex = i)),
    const BusinessesScreen(),
    const UsersScreen(),
    const PasswordManagerScreen(),
    const AuditLogsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return ResponsiveNavWrapper(
      selectedIndex: _currentIndex,
      onItemTap: (i) => setState(() => _currentIndex = i),
      items: _items,
      title: 'Developer Dashboard',
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
    );
  }
}