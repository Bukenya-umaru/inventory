import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../services/auth_provider.dart';
import '../../widgets/stat_card.dart';
import '../../utils/theme.dart';

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
    final auth = context.watch<AuthProvider>();
    final branding = auth.branding;
    final size = MediaQuery.of(context).size;
    final isSmall = size.height < 600 || size.width < 400;

    if (_loading) return const Center(child: CircularProgressIndicator());
    final d = _data ?? {};

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: EdgeInsets.all(isSmall ? 12 : 16),
        children: [
          // Business branding
          Card(
            child: Padding(
              padding: EdgeInsets.all(isSmall ? 14 : 20),
              child: Row(
                children: [
                  if (branding?.businessLogo != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network('http://10.0.2.2:5000${branding!.businessLogo!}',
                        height: isSmall ? 36 : 48,
                        errorBuilder: (_, __, ___) => Icon(Icons.business, size: isSmall ? 36 : 48)),
                    )
                  else
                    CircleAvatar(
                      radius: isSmall ? 18 : 24,
                      backgroundColor: AppTheme.primary,
                      child: Icon(Icons.business, color: Colors.white, size: isSmall ? 20 : 24),
                    ),
                  SizedBox(width: isSmall ? 10 : 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(branding?.businessName ?? 'Business',
                          style: TextStyle(fontSize: isSmall ? 16 : 20, fontWeight: FontWeight.bold)),
                        Text('Welcome back, ${auth.user?.name}!',
                          style: TextStyle(color: Colors.grey.shade500, fontSize: isSmall ? 12 : 14)),
                        if (branding?.phoneNumber != null)
                          Text(branding!.phoneNumber!, style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: isSmall ? 10 : 16),
          // Stats grid - responsive columns
          GridView.count(
            crossAxisCount: size.width > 900 ? 4 : size.width > 600 ? 2 : 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: isSmall ? 8 : 12,
            crossAxisSpacing: isSmall ? 8 : 12,
            childAspectRatio: isSmall ? 1.8 : 1.6,
            children: [
              StatCard(icon: Icons.attach_money, iconColor: AppTheme.success,
                value: '\$${(d['today']?['revenue'] ?? 0).toStringAsFixed(2)}', label: "Today's Revenue"),
              StatCard(icon: Icons.trending_up, iconColor: AppTheme.primary,
                value: '\$${(d['today']?['profit'] ?? 0).toStringAsFixed(2)}', label: "Today's Profit"),
              StatCard(icon: Icons.inventory, iconColor: Colors.purple,
                value: '${d['productCount'] ?? 0}', label: 'Products'),
              StatCard(icon: Icons.people_outline, iconColor: Colors.orange,
                value: '${d['employeeCount'] ?? 0}', label: 'Employees'),
            ],
          ),
          SizedBox(height: isSmall ? 10 : 16),
          // Monthly
          Card(
            child: Padding(
              padding: EdgeInsets.all(isSmall ? 12 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Monthly Overview',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: isSmall ? 14 : 16)),
                  SizedBox(height: isSmall ? 8 : 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _metric('\$${(d['monthly']?['revenue'] ?? 0).toStringAsFixed(2)}', 'Revenue', isSmall),
                      _metric('\$${(d['monthly']?['profit'] ?? 0).toStringAsFixed(2)}', 'Profit', isSmall, color: AppTheme.success),
                      _metric('${d['monthly']?['salesCount'] ?? 0}', 'Sales', isSmall),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metric(String value, String label, bool isSmall, {Color? color}) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: isSmall ? 14 : 18, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: isSmall ? 10 : 12, color: Colors.grey.shade500)),
      ],
    );
  }
}
