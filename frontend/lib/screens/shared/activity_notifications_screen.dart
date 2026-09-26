import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/audit_log.dart';
import '../../services/api_service.dart';
import '../../services/app_events.dart';
import '../../services/notification_sound_service.dart';
import '../../utils/theme.dart';
import '../../widgets/section_search_bar.dart';

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
  String _searchQuery = '';

  static const Map<String, List<String>> _filterGroups = {
    'Sales': ['sale_recorded'],
    'Purchases': [
      'purchase_recorded',
      'purchase_edited',
      'purchase_approved',
      'stock_merged',
      'credit_paid',
    ],
    'Expenses': ['expense_recorded'],
    'Damages': ['damage_recorded'],
    'Low Stock': ['low_stock_alert'],
    'Stock': ['product_created', 'product_updated', 'product_deleted'],
    'Categories': ['category_created', 'category_updated', 'category_deleted'],
    'Suppliers': ['supplier_created', 'supplier_updated', 'supplier_deleted'],
    'Employees': [
      'employee_created_primary',
      'employee_created_backup',
      'employee_deleted',
      'employee_permissions_updated',
      'employee_suspended',
      'employee_reactivated',
    ],
  };
  final Set<String> _selectedFilters = {};

  List<AuditLog> get _visibleLogs => _logs
      .where(
        (log) => matchesSectionSearch(_searchQuery, [
          log.action,
          log.eventType,
          log.userName,
          log.userRole,
          log.businessName,
        ]),
      )
      .toList();

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
    if ([
      'sales',
      'purchases',
      'damages',
      'products',
      'categories',
    ].contains(event)) {
      _load(silent: true);
    }
    if (event == 'low_stock') {
      _load(silent: true);
    }
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final types = _selectedFilters
          .expand((f) => _filterGroups[f] ?? <String>[])
          .toList();
      final res = await ApiService.getActivity(
        types: types.isEmpty ? null : types,
        search: _searchQuery,
      );
      final list = (res['logs'] as List)
          .map((l) => AuditLog.fromJson(l))
          .toList();
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity'),
        actions: [
          if (_unreadCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.danger,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$_unreadCount new',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
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
            onPressed: _unreadCount > 0
                ? () {
                    _markSeen();
                  }
                : null,
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    ChoiceChip(
                      label: const Text('All'),
                      selected: _selectedFilters.isEmpty,
                      onSelected: (_) {
                        setState(() => _selectedFilters.clear());
                        _load(silent: true);
                      },
                    ),
                    ..._filterGroups.keys.map((key) {
                      final selected = _selectedFilters.contains(key);
                      return ChoiceChip(
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
                      );
                    }),
                  ],
                ),
              ),
              SectionSearchBar(
                hintText: 'Search activity...',
                onSearch: (query) {
                  setState(() => _searchQuery = query);
                  _load(silent: true);
                },
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.cloud_off,
                              size: 40,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _error!,
                              style: TextStyle(
                                color: AppTheme.secondaryText(context),
                              ),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton(
                              onPressed: _load,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : _visibleLogs.isEmpty
                    ? RefreshIndicator(
                        onRefresh: () => _load(silent: true),
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(
                              height: MediaQuery.of(context).size.height * 0.35,
                            ),
                            Center(
                              child: Text(
                                _searchQuery.isNotEmpty
                                    ? 'No activity matches your search'
                                    : _selectedFilters.isEmpty
                                    ? 'No activity yet'
                                    : 'No activity for the selected filters',
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => _load(silent: true),
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(8),
                          itemCount: _visibleLogs.length,
                          itemBuilder: (ctx, i) {
                            final log = _visibleLogs[i];
                            final isNew = i < _unreadCount;
                            return _activityTile(log, isNew);
                          },
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _activityTile(AuditLog log, bool isNew) {
    final icon = _eventIcon(log.eventType);
    final color = _severityColor(log.severity);
    final time = DateFormat('MMM d, HH:mm').format(log.timestamp);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: ListTile(
        dense: true,
        visualDensity: const VisualDensity(horizontal: 0, vertical: -2),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        onTap: () => Navigator.of(context).pop(log),
        leading: Stack(
          clipBehavior: Clip.none,
          children: [
            CircleAvatar(
              radius: 18,
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
                    border: Border.all(
                      color: Theme.of(context).cardColor,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
          ],
        ),
        title: Text(
          (log.action?.isNotEmpty == true)
              ? log.action!
              : _eventLabel(log.eventType),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: isNew ? FontWeight.w600 : FontWeight.w500,
            fontSize: 12,
          ),
        ),
        subtitle: Text(
          '${_eventLabel(log.eventType)} • ${log.userName ?? 'System'} • $time',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 10,
            color: AppTheme.secondaryText(context),
          ),
        ),
        trailing: const Icon(Icons.chevron_right, size: 18),
      ),
    );
  }

  static IconData _eventIcon(String eventType) {
    return switch (eventType) {
      'sale_recorded' => Icons.shopping_cart,
      'purchase_recorded' ||
      'purchase_edited' ||
      'purchase_approved' ||
      'credit_paid' => Icons.local_shipping,
      'expense_recorded' => Icons.payments,
      'damage_recorded' => Icons.warning_amber,
      'low_stock_alert' => Icons.production_quantity_limits,
      'stock_merged' => Icons.inventory,
      'product_created' => Icons.add_box,
      'product_updated' => Icons.edit,
      'product_deleted' => Icons.delete_outline,
      'category_created' ||
      'category_updated' ||
      'category_deleted' => Icons.category,
      'supplier_created' ||
      'supplier_updated' ||
      'supplier_deleted' => Icons.local_shipping,
      'login_success' => Icons.login,
      'login_failed' => Icons.block,
      'password_changed' || 'password_viewed' => Icons.lock,
      'admin_created' ||
      'employee_created_primary' ||
      'employee_created_backup' ||
      'employee_deleted' ||
      'employee_permissions_updated' ||
      'employee_suspended' ||
      'employee_reactivated' => Icons.person,
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
      'purchase_edited' => 'Purchase edited',
      'purchase_approved' => 'Purchase approved',
      'credit_paid' => 'Credit marked paid',
      'expense_recorded' => 'Expense recorded',
      'damage_recorded' => 'Damage reported',
      'low_stock_alert' => 'Low stock alert',
      'stock_merged' => 'Stock merged',
      'product_created' => 'Product added',
      'product_updated' => 'Product updated',
      'product_deleted' => 'Product deleted',
      'category_created' => 'Category added',
      'category_updated' => 'Category updated',
      'category_deleted' => 'Category deleted',
      'supplier_created' => 'Supplier added',
      'supplier_updated' => 'Supplier updated',
      'supplier_deleted' => 'Supplier deleted',
      'login_success' => 'Login',
      'login_failed' => 'Failed login',
      'password_changed' => 'Password changed',
      'password_viewed' => 'Password viewed',
      'admin_created' => 'Admin account created',
      'employee_created_primary' => 'Employee account created',
      'employee_created_backup' => 'Backup account created',
      'employee_deleted' => 'Employee removed',
      'employee_permissions_updated' => 'Permissions updated',
      'employee_suspended' => 'Employee suspended',
      'employee_reactivated' => 'Employee reactivated',
      'business_created' => 'Business created',
      'business_suspended' => 'Business suspended',
      'business_reactivated' => 'Business reactivated',
      'business_deleted' => 'Business deleted',
      'business_updated' => 'Business updated',
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
