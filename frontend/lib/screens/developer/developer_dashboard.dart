import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../widgets/stat_card.dart';
import '../../utils/theme.dart';

class DeveloperDashboard extends StatefulWidget {
  const DeveloperDashboard({super.key});
  @override
  State<DeveloperDashboard> createState() => _DeveloperDashboardState();
}

class _DeveloperDashboardState extends State<DeveloperDashboard> {
  Map<String, dynamic>? _stats;
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final res = await ApiService.getTenantStats();
      setState(() { _stats = res['stats']; _loading = false; });
    } catch (e) { setState(() { _loading = false; }); }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_stats == null) return const Center(child: Text('Failed to load stats'));

    final s = _stats!;
    final size = MediaQuery.of(context).size;
    final isSmall = size.height < 600 || size.width < 400;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: EdgeInsets.all(isSmall ? 12 : 16),
        children: [
          Text('System Overview',
            style: TextStyle(fontSize: isSmall ? 18 : 20, fontWeight: FontWeight.bold)),
          SizedBox(height: isSmall ? 10 : 16),
          GridView.count(
            crossAxisCount: size.width > 900 ? 4 : size.width > 600 ? 2 : 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: isSmall ? 8 : 12,
            crossAxisSpacing: isSmall ? 8 : 12,
            childAspectRatio: isSmall ? 1.8 : 1.6,
            children: [
              StatCard(icon: Icons.business, iconColor: AppTheme.primary,
                value: '${s['totalBusinesses'] ?? 0}', label: 'Total Businesses',
                subtitle: '${s['activeBusinesses'] ?? 0} active'),
              StatCard(icon: Icons.people, iconColor: AppTheme.success,
                value: '${s['totalUsers'] ?? 0}', label: 'Total Users',
                subtitle: '${s['totalAdmins'] ?? 0} admins / ${s['totalEmployees'] ?? 0} employees'),
              StatCard(icon: Icons.pause_circle, iconColor: AppTheme.warning,
                value: '${s['suspendedBusinesses'] ?? 0}', label: 'Suspended'),
              StatCard(icon: Icons.delete_outline, iconColor: AppTheme.danger,
                value: '${s['deletedBusinesses'] ?? 0}', label: 'Deleted'),
            ],
          ),
          SizedBox(height: isSmall ? 10 : 16),
          Card(
            child: Padding(
              padding: EdgeInsets.all(isSmall ? 12 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Business Capacity: ${s['totalBusinesses'] ?? 0} / ${s['maxBusinesses'] ?? 1000}',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: isSmall ? 13 : 15)),
                  SizedBox(height: isSmall ? 6 : 8),
                  LinearProgressIndicator(
                    value: ((s['totalBusinesses'] ?? 0) / (s['maxBusinesses'] ?? 1000)).toDouble(),
                    backgroundColor: Colors.grey.shade200,
                    color: AppTheme.primary,
                    minHeight: isSmall ? 6 : 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
