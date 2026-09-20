import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/audit_log.dart';
import '../../services/api_service.dart';
import '../../services/app_events.dart';
import '../../services/notification_sound_service.dart';
import '../../utils/theme.dart';

class ActivityNotificationsScreen extends StatefulWidget {
  const ActivityNotificationsScreen({super.key});
  @override
  State<ActivityNotificationsScreen> createState() =>
      _ActivityNotificationsScreenState();
}

class _ActivityNotificationsScreenState
    extends State<ActivityNotificationsScreen> {
  List<AuditLog> _logs = [];
  int _unreadCount = 0;
  bool _loading = true;
  String? _error;
  AuditLog? _detail; 

  static const Map<String, List<String>> _filterGroups = {
    'Sales': ['sale_recorded'],
    'Purchases': ['purchase_recorded', 'stock_merged'],
    'Damages': ['damage_recorded'],
    'Stock': ['product_created', 'product_updated', 'product_deleted'],
    'Categories': ['category_created', 'category_updated', 'category_deleted'],
  };
  final Set<String> _selectedFilters = {}; 

  @override
  void initState() {
    super.initState();
    _load();

    AppEvents.instance.subscribe(_onEvent);
  }

  @override
  void dispose() {
    AppEvents.instance.unsubscribe(_onEvent);
    super.dispose();
  }

  void _onEvent(String event) {
    if (!mounted) return;
    if (['sales', 'purchases', 'damages', 'products', 'categories'].contains(event)) {
      _load(silent: true);
    }
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final types = _selectedFilters
          .expand((f) => _filterGroups[f] ?? <String>[])
          .toList();
      final res = await ApiService.getActivity(types: types.isEmpty ? null : types);
      final list =
          (res['logs'] as List).map((l) => AuditLog.fromJson(l)).toList();
      setState(() {
        _logs = list;
        _unreadCount = (res['unreadCount'] ?? 0) as int;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Could not load activity. Is the server running?';
      });
    }
  }

  Future<void> _markSeen() async {
    try {
      await ApiService.markActivitiesSeen();
      if (mounted) setState(() => _unreadCount = 0);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {

    if (_detail != null) {
      return _buildDetail(_detail!);
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity'),
        actions: [
          if (_unreadCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.danger,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('$_unreadCount new',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ),
              ),
            ),

          ValueListenableBuilder<bool>(
            valueListenable: NotificationSoundService.instance.mutedNotifier,
            builder: (ctx, muted, _) => IconButton(
              icon: Icon(muted ? Icons.volume_off : Icons.volume_up),
              tooltip: muted ? 'Sound is muted' : 'Sound is on',
              onPressed: () =>
                  NotificationSoundService.instance.setMuted(!muted),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.done_all),
            tooltip: 'Mark all as seen',
            onPressed:
                _unreadCount > 0 ? () { _markSeen(); } : null,
          ),
        ],
      ),
      body: Column(
        children: [

          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: const Text('All'),
                    selected: _selectedFilters.isEmpty,
                    onSelected: (_) {
                      setState(() => _selectedFilters.clear());
                      _load(silent: true);
                    },
                  ),
                ),
                ..._filterGroups.keys.map((key) {
                  final selected = _selectedFilters.contains(key);
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(key),
                      selected: selected,
                      onSelected: (on) {
                        setState(() {
                          if (on) {
                            _selectedFilters.add(key);
                          } else {
                            _selectedFilters.remove(key);
                          }
                        });
                        _load(silent: true);
                      },
                    ),
                  );
                }),
              ],
            ),
          ),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.cloud_off, size: 40, color: Colors.grey),
                            const SizedBox(height: 12),
                            Text(_error!,
                                style: TextStyle(
                                    color: AppTheme.secondaryText(context))),
                            const SizedBox(height: 12),
                            ElevatedButton(
                                onPressed: _load, child: const Text('Retry')),
                          ],
                        ),
                      )
                    : _logs.isEmpty
                        ? Center(
                            child: Text(_selectedFilters.isEmpty
                                ? 'No activity yet'
                                : 'No activity for the selected filters'),
                          )
                        : RefreshIndicator(
                            onRefresh: () async {
                              await _load(silent: true);
                            },
                            child: ListView.builder(
                              padding: const EdgeInsets.all(8),
                              itemCount: _logs.length,
                              itemBuilder: (ctx, i) {
                                final log = _logs[i];
                                final isNew = i < _unreadCount;
                                return _activityTile(log, isNew);
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _activityTile(AuditLog log, bool isNew) {
    final icon = _eventIcon(log.eventType);
    final color = _severityColor(log.severity);
    final time = DateFormat('MMM d, HH:mm').format(log.timestamp);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: ListTile(
        onTap: () => setState(() => _detail = log),
        leading: Stack(
          clipBehavior: Clip.none,
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.12),
              child: Icon(icon, color: color, size: 20),
            ),
            if (isNew)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: AppTheme.danger,
                    shape: BoxShape.circle,
                    border: Border.all(color: Theme.of(context).cardColor, width: 1.5),
                  ),
                ),
              ),
          ],
        ),
        title: Text(
          (log.action?.isNotEmpty == true) ? log.action! : _eventLabel(log.eventType),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: isNew ? FontWeight.w600 : FontWeight.w500,
            fontSize: 13,
          ),
        ),
        subtitle: Text(
          '${_eventLabel(log.eventType)} • ${log.userName ?? 'System'} • $time',
          style: TextStyle(fontSize: 11, color: AppTheme.secondaryText(context)),
        ),
        trailing: const Icon(Icons.chevron_right, size: 18),
      ),
    );
  }

  Widget _buildDetail(AuditLog log) {
    final df = DateFormat('EEEE, MMM d, yyyy • HH:mm');
    final color = _severityColor(log.severity);
    final details = <String, String>{
      'Activity': _eventLabel(log.eventType),
      'Description': log.action ?? '',
      'Made by': '${log.userName ?? 'System'} (${log.userRole ?? '-'})',
      'When': df.format(log.timestamp),
      'Severity': log.severity,
      if (log.businessName?.isNotEmpty == true) 'Business': log.businessName!,
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Activity Detail')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: CircleAvatar(
              radius: 32,
              backgroundColor: color.withValues(alpha: 0.12),
              child: Icon(_eventIcon(log.eventType), color: color, size: 32),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: details.entries
                    .map((e) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 110,
                                child: Text(e.key,
                                    style: TextStyle(
                                        fontSize: 13,
                                        color:
                                            AppTheme.secondaryText(context))),
                              ),
                              Expanded(
                                child: Text(
                                  e.value.isEmpty ? '-' : e.value,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ))
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static IconData _eventIcon(String eventType) {
    return switch (eventType) {
      'sale_recorded' => Icons.shopping_cart,
      'purchase_recorded' => Icons.local_shipping,
      'damage_recorded' => Icons.warning_amber,
      'stock_merged' => Icons.inventory,
      'product_created' => Icons.add_box,
      'product_updated' => Icons.edit,
      'product_deleted' => Icons.delete_outline,
      'category_created' || 'category_updated' || 'category_deleted' =>
        Icons.category,
      'login_success' => Icons.login,
      'login_failed' => Icons.block,
      'password_changed' || 'password_viewed' => Icons.lock,
      'admin_created' ||
      'employee_created_primary' ||
      'employee_created_backup' ||
      'employee_deleted' ||
      'employee_permissions_updated' => Icons.person,
      'business_created' ||
      'business_suspended' ||
      'business_reactivated' ||
      'business_deleted' => Icons.store,
      _ => Icons.notifications,
    };
  }

  static String _eventLabel(String eventType) {
    return switch (eventType) {
      'sale_recorded' => 'Sale recorded',
      'purchase_recorded' => 'Purchase recorded',
      'damage_recorded' => 'Damage reported',
      'stock_merged' => 'Stock merged',
      'product_created' => 'Product added',
      'product_updated' => 'Product updated',
      'product_deleted' => 'Product deleted',
      'category_created' => 'Category added',
      'category_updated' => 'Category updated',
      'category_deleted' => 'Category deleted',
      'login_success' => 'Login',
      'login_failed' => 'Failed login',
      'password_changed' => 'Password changed',
      'password_viewed' => 'Password viewed',
      'admin_created' => 'Admin account created',
      'employee_created_primary' => 'Employee account created',
      'employee_created_backup' => 'Backup account created',
      'employee_deleted' => 'Employee removed',
      'employee_permissions_updated' => 'Permissions updated',
      'business_created' => 'Business created',
      'business_suspended' => 'Business suspended',
      'business_reactivated' => 'Business reactivated',
      'business_deleted' => 'Business deleted',
      _ => eventType,
    };
  }

  static Color _severityColor(String severity) {
    return switch (severity) {
      'warning' => AppTheme.warning,
      'error' || 'critical' => AppTheme.danger,
      'info' => AppTheme.success,
      _ => Colors.grey,
    };
  }
}