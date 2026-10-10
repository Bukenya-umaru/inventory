import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/app_events.dart';
import '../../models/user.dart';
import '../../utils/theme.dart';
import '../../widgets/compact_data_table.dart';
import '../../widgets/loading_button.dart';
import '../../widgets/app_drawer.dart' show ThemeToggleFab;
import '../../widgets/section_search_bar.dart';

const _allPermissions = [
  'manage_categories',
  'create_products',
  'edit_products',
  'delete_products',
  'record_sales',
  'record_purchases',
  'record_damages',
  'record_expenses',
  'approve_sales',
  'approve_credits',
  'view_inventory',
  'view_transactions',
  'view_profits',
  'adjust_inventory',
  'view_reports',
];

const _permLabels = {
  'manage_categories': 'Manage Categories',
  'create_products': 'Create Products',
  'edit_products': 'Edit Products',
  'delete_products': 'Delete Products',
  'record_sales': 'Record Sales',
  'record_purchases': 'Record Purchases',
  'record_damages': 'Record Damages',
  'record_expenses': 'Record Expenses',
  'approve_sales': 'Approve Sales',
  'approve_credits': 'Approve Credits',
  'view_inventory': 'View Inventory',
  'view_transactions': 'View Transactions',
  'view_profits': 'View Profits',
  'adjust_inventory': 'Adjust Inventory',
  'view_reports': 'View Reports',
};

class EmployeesScreen extends StatefulWidget {
  const EmployeesScreen({super.key});
  @override
  State<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends State<EmployeesScreen> {
  List<User> _employees = [];
  bool _loading = true;
  String? _viewingUserId;
  String? _revealedPassword;
  int _countdown = 0;
  Timer? _timer;
  String _searchQuery = '';

  List<User> get _visibleEmployees => _employees
      .where(
        (employee) => matchesSectionSearch(_searchQuery, [
          employee.name,
          employee.email,
          employee.employeeId,
          employee.department,
          employee.position,
        ]),
      )
      .toList();

  @override
  void initState() {
    super.initState();
    _load();
    AppEvents.instance.subscribe(_onEvent);
  }

  void _onEvent(String event) {
    if (!mounted) return;
    final globalQuery = AppEvents.globalSearchQuery(event);
    if (globalQuery != null) {
      setState(() => _searchQuery = globalQuery);
    }
  }

  @override
  void dispose() {
    AppEvents.instance.unsubscribe(_onEvent);
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.getUsers(role: 'employee');
      final list = (res['users'] as List).map((u) => User.fromJson(u)).toList();
      setState(() {
        _employees = list;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _viewPassword(String userId) async {
    try {
      final res = await ApiService.viewPassword(userId);
      setState(() {
        _viewingUserId = userId;
        _revealedPassword = res['password'];
        _countdown = res['visibleFor'] ?? 30;
      });
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        setState(() {
          _countdown--;
          if (_countdown <= 0) {
            _revealedPassword = null;
            _viewingUserId = null;
            t.cancel();
          }
        });
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Compose the shared dark-mode toggle with this tab's own action.
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ThemeToggleFab(mini: true),
          const SizedBox(height: 12),
          FloatingActionButton(
            // No hero: the nav wrapper's toggle FAB lives on the same route.
            heroTag: null,
            onPressed: () => _showCreate(),
            child: const Icon(Icons.person_add),
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 12),
          SectionSearchBar(
            hintText: 'Search employees...',
            onSearch: (query) => setState(() => _searchQuery = query),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _visibleEmployees.isEmpty
                ? RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 220),
                        Center(
                          child: Text(
                            _searchQuery.isEmpty
                                ? 'No employees found'
                                : 'No employees match your search',
                          ),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(onRefresh: _load, child: _employeesTable()),
          ),
        ],
      ),
    );
  }

  /// Compact table view.
  Widget _employeesTable() {
    final rows = <CompactDataRow>[];
    final employees = _visibleEmployees;
    for (var i = 0; i < employees.length; i++) {
      final e = employees[i];
      final isRevealed = _viewingUserId == e.id && _revealedPassword != null;
      rows.add(
        CompactDataRow([
          Row(
            children: [
              CircleAvatar(
                radius: 13,
                backgroundColor: AppTheme.success.withValues(alpha: 0.1),
                child: Text(
                  e.name[0].toUpperCase(),
                  style: const TextStyle(
                    color: AppTheme.success,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: CompactDataTable.accent(context, e.name)),
            ],
          ),
          CompactDataTable.muted(context, e.email),
          CompactDataTable.chip(
            context,
            e.role[0].toUpperCase() + e.role.substring(1),
            e.isAdmin
                ? AppTheme.blueBright(context)
                : AppTheme.successBright(context),
          ),
          CompactDataTable.cell(context, '${e.permissions.length}'),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isRevealed
                  ? AppTheme.passwordRevealedBg(context)
                  : AppTheme.passwordHiddenBg(context),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isRevealed ? Icons.visibility : Icons.visibility_off,
                  size: 14,
                  color: isRevealed
                      ? AppTheme.success
                      : AppTheme.mutedIcon(context),
                ),
                const SizedBox(width: 6),
                Text(
                  isRevealed ? _revealedPassword! : '••••••••',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: AppTheme.fontSize(context, 11),
                    fontWeight: FontWeight.w600,
                    color: isRevealed
                        ? AppTheme.textColor(context)
                        : AppTheme.mutedIcon(context),
                  ),
                ),
                if (isRevealed) ...[
                  const SizedBox(width: 6),
                  Text(
                    '$_countdown s',
                    style: TextStyle(
                      fontSize: AppTheme.fontSize(context, 10),
                      color: AppTheme.warning,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ],
            ),
          ),
          CompactDataTable.actions([
            CompactDataTable.actionIcon(
              icon: Icons.key,
              color: AppTheme.warningBright(context),
              tooltip: isRevealed ? 'Password revealed' : 'Show password',
              onTap: isRevealed ? null : () => _viewPassword(e.id),
            ),
            CompactDataTable.actionIcon(
              icon: Icons.vpn_key,
              color: AppTheme.blueBright(context),
              tooltip: 'Manage Permissions',
              onTap: () => _showPermissions(e),
            ),
            CompactDataTable.actionIcon(
              icon: Icons.delete_outline,
              color: AppTheme.dangerBright(context),
              tooltip: 'Delete',
              onTap: () => _deleteEmployee(e),
            ),
            CompactDataTable.actionIcon(
              icon: e.accountStatus == 'suspended'
                  ? Icons.play_arrow
                  : Icons.pause,
              color: e.accountStatus == 'suspended'
                  ? AppTheme.success
                  : AppTheme.warning,
              tooltip: e.accountStatus == 'suspended'
                  ? 'Reactivate employee'
                  : 'Suspend employee',
              onTap: () => _toggleEmployeeStatus(e),
            ),
          ]),
        ]),
      );
    }

    return Padding(
      padding: EdgeInsets.all(AppTheme.pad(context, 16)),
      child: CompactDataTable(
        columns: const [
          CompactTableColumn('Employee', flex: 3),
          CompactTableColumn('Email', flex: 3),
          CompactTableColumn('Role', flex: 2),
          CompactTableColumn('Perms', flex: 1),
          CompactTableColumn('Password', flex: 3),
          CompactTableColumn('Actions', flex: 2, rightAligned: true),
        ],
        rows: rows,
      ),
    );
  }

  void _showCreate() {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create Employee'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailCtrl,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passCtrl,
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          LoadingElevatedButton(
            loadingChild: const Text('Creating...'),
            onPressed: () async {
              if (nameCtrl.text.isEmpty ||
                  emailCtrl.text.isEmpty ||
                  passCtrl.text.isEmpty)
                return;
              try {
                await ApiService.createUser({
                  'name': nameCtrl.text,
                  'email': emailCtrl.text,
                  'password': passCtrl.text,
                });
                if (ctx.mounted) Navigator.pop(ctx);
                _load();
              } catch (e) {
                if (ctx.mounted)
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showPermissions(User employee) {
    List<String> selected = List.from(employee.permissions);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Permissions - ${employee.name}'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: _allPermissions
                  .map(
                    (p) => CheckboxListTile(
                      value: selected.contains(p),
                      title: Text(
                        _permLabels[p] ?? p,
                        style: TextStyle(
                          fontSize: AppTheme.fontSize(context, 13),
                        ),
                      ),
                      onChanged: (v) {
                        setDialogState(() {
                          if (v == true) {
                            selected.add(p);
                          } else {
                            selected.remove(p);
                          }
                        });
                      },
                    ),
                  )
                  .toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            LoadingElevatedButton(
              loadingChild: const Text('Saving...'),
              onPressed: () async {
                await ApiService.updatePermissions(employee.id, selected);
                if (ctx.mounted) Navigator.pop(ctx);
                _load();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteEmployee(User employee) {
    final reasons = [
      'Employee Resigned/Left Company',
      'Employee Terminated',
      'Employee Requested Account Removal',
    ];
    String selectedReason = reasons.first;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Employee - Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Employee: ${employee.name}'),
            Text(
              'Email: ${employee.email}',
              style: TextStyle(
                fontSize: AppTheme.fontSize(context, 12),
                color: AppTheme.secondaryText(context),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Deleting this employee will:',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const Text(
              '• Remove all access to the system\n• Preserve transaction history (for audit)\n• Notify Admin of deletion',
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: selectedReason,
              isExpanded: true,
              items: reasons
                  .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                  .toList(),
              onChanged: (v) => selectedReason = v!,
              decoration: const InputDecoration(labelText: 'Reason'),
            ),
            const SizedBox(height: 8),
            Text(
              'Request will be sent to Developer for approval',
              style: TextStyle(
                fontSize: AppTheme.fontSize(context, 12),
                color: AppTheme.warning,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () async {
              await ApiService.deleteUser(employee.id, reason: selectedReason);
              if (ctx.mounted) Navigator.pop(ctx);
              _load();
            },
            child: const Text('Submit Deletion Request'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleEmployeeStatus(User employee) async {
    if (employee.accountStatus == 'suspended') {
      await ApiService.reactivateUser(employee.id);
      _load();
      return;
    }
    final reason = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Suspend Employee'),
        content: TextField(
          controller: reason,
          decoration: const InputDecoration(labelText: 'Reason'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Suspend'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ApiService.suspendUser(employee.id, reason: reason.text.trim());
      _load();
    }
  }
}
