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

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Business branding
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                if (branding?.businessLogo != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network('http://10.0.2.2:5000${branding!.businessLogo!}',
                      height: 48, errorBuilder: (_, __, ___) => const Icon(Icons.business, size: 48)),
                  )
                else
                  const CircleAvatar(radius: 24, backgroundColor: AppTheme.success,
                    child: Icon(Icons.person, color: Colors.white)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(branding?.businessName ?? 'Business',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      Text('Welcome, ${auth.user?.name}!',
                        style: TextStyle(color: Colors.grey.shade500)),
                      if (branding?.phoneNumber != null)
                        Text(branding!.phoneNumber!, style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        // Permission-based quick actions
        const Text('Quick Actions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            if (auth.user?.hasPermission('view_inventory') == true)
              _actionCard(Icons.inventory, 'Products', Colors.blue),
            if (auth.user?.hasPermission('record_sales') == true)
              _actionCard(Icons.shopping_cart, 'Sales', Colors.green),
            if (auth.user?.hasPermission('record_damages') == true)
              _actionCard(Icons.warning, 'Damages', Colors.red),
            if (auth.user?.hasPermission('view_reports') == true)
              _actionCard(Icons.bar_chart, 'Reports', Colors.purple),
          ],
        ),
      ],
    );
  }

  Widget _actionCard(IconData icon, String label, Color color) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(icon, size: 28, color: color),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
