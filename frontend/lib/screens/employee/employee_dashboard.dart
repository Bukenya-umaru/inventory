import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_provider.dart';
import '../../utils/theme.dart';

class EmployeeDashboard extends StatelessWidget {
  const EmployeeDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final branding = auth.branding;
    final size = MediaQuery.of(context).size;
    final isWide = size.width >= 900;

    return RefreshIndicator(
      onRefresh: () async {},
      child: isWide ? _wideLayout(context, auth, branding) : _mobileLayout(context, auth, branding),
    );
  }

  Widget _wideLayout(BuildContext context, dynamic auth, dynamic branding) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // Welcome + Quick Actions row
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: _sectionCard(context,
                title: 'Welcome, ${auth.user?.name ?? 'Employee'}!',
                child: Row(
                  children: [
                    if (branding?.businessLogo != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network('http://10.0.2.2:5000${branding!.businessLogo!}',
                          height: 40, errorBuilder: (_, __, ___) => const Icon(Icons.business, size: 40)),
                      )
                    else
                      CircleAvatar(radius: 20, backgroundColor: AppTheme.success, child: const Icon(Icons.person, color: Colors.white)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(branding?.businessName ?? 'Business',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textColor(context))),
                          Text('Welcome back, ${auth.user?.name}!',
                            style: TextStyle(color: AppTheme.secondaryText(context), fontSize: 14)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: _sectionCard(context,
                title: 'Quick Actions',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (auth.user?.hasPermission('view_inventory') == true)
                      _actionCard(context, Icons.inventory, 'Products', Colors.blue),
                    if (auth.user?.hasPermission('record_sales') == true)
                      _actionCard(context, Icons.shopping_cart, 'Sales', Colors.green),
                    if (auth.user?.hasPermission('record_damages') == true)
                      _actionCard(context, Icons.warning, 'Damages', Colors.red),
                    if (auth.user?.hasPermission('view_reports') == true)
                      _actionCard(context, Icons.bar_chart, 'Reports', Colors.purple),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _mobileLayout(BuildContext context, dynamic auth, dynamic branding) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionCard(context,
          title: 'Welcome, ${auth.user?.name ?? 'Employee'}!',
          child: Column(
            children: [
              if (branding?.businessLogo != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network('http://10.0.2.2:5000${branding!.businessLogo!}',
                    height: 40, errorBuilder: (_, __, ___) => const Icon(Icons.business, size: 40)),
                )
              else
                CircleAvatar(radius: 20, backgroundColor: AppTheme.success, child: const Icon(Icons.person, color: Colors.white)),
              const SizedBox(height: 12),
              Text(branding?.businessName ?? 'Business',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textColor(context))),
              Text('Welcome back, ${auth.user?.name}!',
                style: TextStyle(color: AppTheme.secondaryText(context), fontSize: 14)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _sectionCard(context,
          title: 'Quick Actions',
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              if (auth.user?.hasPermission('view_inventory') == true)
                _actionCard(context, Icons.inventory, 'Products', Colors.blue),
              if (auth.user?.hasPermission('record_sales') == true)
                _actionCard(context, Icons.shopping_cart, 'Sales', Colors.green),
              if (auth.user?.hasPermission('record_damages') == true)
                _actionCard(context, Icons.warning, 'Damages', Colors.red),
              if (auth.user?.hasPermission('view_reports') == true)
                _actionCard(context, Icons.bar_chart, 'Reports', Colors.purple),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionCard(BuildContext context, {required String title, required Widget child}) {
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

  Widget _actionCard(BuildContext context, IconData icon, String label, Color color) {
    return Container(
      width: 120,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, size: 24, color: color),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: color)),
        ],
      ),
    );
  }
}
