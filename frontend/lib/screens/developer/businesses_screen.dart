import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../models/tenant.dart';
import '../../utils/theme.dart';

class BusinessesScreen extends StatefulWidget {
  const BusinessesScreen({super.key});
  @override
  State<BusinessesScreen> createState() => _BusinessesScreenState();
}

class _BusinessesScreenState extends State<BusinessesScreen> {
  List<Tenant> _tenants = [];
  bool _loading = true;
  String _statusFilter = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.getTenants(status: _statusFilter.isNotEmpty ? _statusFilter : null);
      final list = (res['tenants'] as List).map((t) => Tenant.fromJson(t)).toList();
      setState(() { _tenants = list; _loading = false; });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Filters
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Expanded(child: Text('Businesses', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: '', label: Text('All')),
                  ButtonSegment(value: 'active', label: Text('Active')),
                  ButtonSegment(value: 'suspended', label: Text('Suspended')),
                  ButtonSegment(value: 'deleted', label: Text('Deleted')),
                ],
                selected: {_statusFilter},
                onSelectionChanged: (v) { _statusFilter = v.first; _load(); },
              ),
            ],
          ),
        ),
        // List
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _tenants.isEmpty
                  ? const Center(child: Text('No businesses found'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _tenants.length,
                        itemBuilder: (ctx, i) => _TenantCard(
                          tenant: _tenants[i],
                          onRefresh: _load,
                        ),
                      ),
                    ),
        ),
      ],
    );
  }
}

class _TenantCard extends StatelessWidget {
  final Tenant tenant;
  final VoidCallback onRefresh;
  const _TenantCard({required this.tenant, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (tenant.status) {
      'active' => AppTheme.success,
      'suspended' => AppTheme.warning,
      _ => AppTheme.danger,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppTheme.primary.withOpacity(0.1),
                  child: Text(tenant.businessName[0].toUpperCase(),
                    style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tenant.businessName, style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text(tenant.email, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(tenant.status, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: statusColor)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _info('Owner', tenant.ownerName),
                const SizedBox(width: 16),
                _info('Type', tenant.businessType),
                const SizedBox(width: 16),
                _info('Users', '${tenant.userCount}'),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (tenant.status == 'active')
                  TextButton.icon(
                    onPressed: () => _suspend(context),
                    icon: const Icon(Icons.pause, size: 16, color: AppTheme.warning),
                    label: const Text('Suspend', style: TextStyle(color: AppTheme.warning)),
                  ),
                if (tenant.status == 'suspended')
                  TextButton.icon(
                    onPressed: () => _reactivate(),
                    icon: const Icon(Icons.play_arrow, size: 16, color: AppTheme.success),
                    label: const Text('Reactivate', style: TextStyle(color: AppTheme.success)),
                  ),
                if (tenant.status != 'deleted')
                  TextButton.icon(
                    onPressed: () => _delete(context),
                    icon: const Icon(Icons.delete_outline, size: 16, color: AppTheme.danger),
                    label: const Text('Delete', style: TextStyle(color: AppTheme.danger)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _info(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
      ],
    );
  }

  void _suspend(BuildContext context) {
    final reasons = ['Payment Issue', 'Owner Request', 'Compliance Review', 'Temporary Closure'];
    String selected = reasons.first;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Suspend Business'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Suspend "${tenant.businessName}"?'),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: selected,
              items: reasons.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
              onChanged: (v) => selected = v!,
              decoration: const InputDecoration(labelText: 'Reason'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.warning),
            onPressed: () async {
              await ApiService.suspendTenant(tenant.id, selected);
              if (ctx.mounted) Navigator.pop(ctx);
              onRefresh();
            },
            child: const Text('Suspend'),
          ),
        ],
      ),
    );
  }

  Future<void> _reactivate() async {
    await ApiService.reactivateTenant(tenant.id);
    onRefresh();
  }

  void _delete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Business', style: TextStyle(color: AppTheme.danger)),
        content: Text('Permanently delete "${tenant.businessName}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () async {
              await ApiService.deleteTenant(tenant.id);
              if (ctx.mounted) Navigator.pop(ctx);
              onRefresh();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
