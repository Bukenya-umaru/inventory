import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../utils/theme.dart';

class DeveloperDashboard extends StatefulWidget {
  final Function(int)? onNavigateToTab;
  const DeveloperDashboard({super.key, this.onNavigateToTab});
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
    } catch (e) { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_stats == null) return const Center(child: Text('Failed to load stats'));

    final s = _stats!;
    final size = MediaQuery.of(context).size;
    final isWide = size.width >= 900;

    return RefreshIndicator(
      onRefresh: _load,
      child: isWide ? _wideLayout(s) : _mobileLayout(s),
    );
  }

  Widget _wideLayout(dynamic s) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: _sectionCard(
                title: 'System Overview',
                child: Row(
                  children: [
                    _activityStat('${s['totalBusinesses'] ?? 0}', 'Businesses', AppTheme.primary, Icons.business),
                    _activityStat('${s['activeBusinesses'] ?? 0}', 'Active', AppTheme.success, Icons.check_circle),
                    _activityStat('${s['totalUsers'] ?? 0}', 'Users', Colors.purple, Icons.people),
                    _activityStat('${s['totalAdmins'] ?? 0}', 'Admins', Colors.orange, Icons.admin_panel_settings),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: _sectionCard(
                title: 'Capacity',
                child: Column(
                  children: [
                    _summaryRow('Total Businesses', '${s['totalBusinesses'] ?? 0}', Icons.business),
                    const Divider(height: 1),
                    _summaryRow('Active Businesses', '${s['activeBusinesses'] ?? 0}', Icons.check_circle),
                    const Divider(height: 1),
                    _summaryRow('Max Capacity', '${s['maxBusinesses'] ?? 1000}', Icons.speed),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: _sectionCard(
                title: 'Quick Actions',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _actionChip(Icons.add_business, 'Create Business', AppTheme.primary, () => widget.onNavigateToTab?.call(1)),
                    _actionChip(Icons.person_add, 'Create Admin', AppTheme.primary, () => widget.onNavigateToTab?.call(2)),
                    _actionChip(Icons.key, 'View Passwords', AppTheme.warning, () => widget.onNavigateToTab?.call(3)),
                    _actionChip(Icons.shield, 'Audit Logs', AppTheme.primary, () => widget.onNavigateToTab?.call(4)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: _sectionCard(
                title: 'Business Details',
                child: Column(
                  children: [
                    _detailRow('Total Businesses', '${s['totalBusinesses'] ?? 0}'),
                    _detailRow('Suspended', '${s['suspendedBusinesses'] ?? 0}', isWarning: true),
                    _detailRow('Deleted', '${s['deletedBusinesses'] ?? 0}', isDanger: true),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _mobileLayout(dynamic s) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _sectionCard(
          title: 'System Overview',
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: _activityStat('${s['totalBusinesses'] ?? 0}', 'Businesses', AppTheme.primary, Icons.business)),
                  Expanded(child: _activityStat('${s['activeBusinesses'] ?? 0}', 'Active', AppTheme.success, Icons.check_circle)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _activityStat('${s['totalUsers'] ?? 0}', 'Users', Colors.purple, Icons.people)),
                  Expanded(child: _activityStat('${s['totalAdmins'] ?? 0}', 'Admins', Colors.orange, Icons.admin_panel_settings)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _sectionCard(
          title: 'Capacity',
          child: Column(
            children: [
              _summaryRow('Total Businesses', '${s['totalBusinesses'] ?? 0}', Icons.business),
              const Divider(height: 1),
              _summaryRow('Active Businesses', '${s['activeBusinesses'] ?? 0}', Icons.check_circle),
              const Divider(height: 1),
              _summaryRow('Max Capacity', '${s['maxBusinesses'] ?? 1000}', Icons.speed),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _sectionCard(
          title: 'Business Details',
          child: Column(
            children: [
              _detailRow('Total Businesses', '${s['totalBusinesses'] ?? 0}'),
              _detailRow('Suspended', '${s['suspendedBusinesses'] ?? 0}', isWarning: true),
              _detailRow('Deleted', '${s['deletedBusinesses'] ?? 0}', isDanger: true),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _sectionCard(
          title: 'Quick Actions',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _actionChip(Icons.add_business, 'Create Business', AppTheme.primary, () => widget.onNavigateToTab?.call(1)),
              _actionChip(Icons.person_add, 'Create Admin', AppTheme.primary, () => widget.onNavigateToTab?.call(2)),
              _actionChip(Icons.key, 'View Passwords', AppTheme.warning, () => widget.onNavigateToTab?.call(3)),
              _actionChip(Icons.shield, 'Audit Logs', AppTheme.primary, () => widget.onNavigateToTab?.call(4)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionCard({required String title, required Widget child}) {
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

  Widget _activityStat(String value, String label, Color color, IconData icon) {
    return Container(
      margin: const EdgeInsets.all(4),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 11, color: AppTheme.secondaryText(context))),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: TextStyle(fontSize: 14, color: AppTheme.secondaryText(context)))),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textColor(context))),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value, {bool isWarning = false, bool isDanger = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(fontSize: 14, color: isWarning ? AppTheme.warning : isDanger ? AppTheme.danger : AppTheme.secondaryText(context)))),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isWarning ? AppTheme.warning : isDanger ? AppTheme.danger : AppTheme.textColor(context))),
        ],
      ),
    );
  }

  Widget _actionChip(IconData icon, String label, Color color, VoidCallback onTap) {
    return ActionChip(
      avatar: Icon(icon, size: 18, color: color),
      label: Text(label, style: TextStyle(color: color, fontSize: 13)),
      onPressed: onTap,
      backgroundColor: color.withValues(alpha: 0.05),
      side: BorderSide(color: color.withValues(alpha: 0.2)),
    );
  }
}