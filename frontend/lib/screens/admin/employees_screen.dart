import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../models/user.dart';
import '../../utils/theme.dart';
import '../../widgets/app_drawer.dart' show ThemeToggleFab;
import '../../widgets/download_app_fab.dart' show DownloadAppFab;

const _allPermissions = [
  'manage_categories',
  'create_products',
  'edit_products',
  'delete_products',
  'record_sales',
  'record_purchases',
  'record_damages',
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.getUsers(role: 'employee');
      final list = (res['users'] as List).map((u) => User.fromJson(u)).toList();
      setState(() { _employees = list; _loading = false; });
    } catch (e) { setState(() => _loading = false); }
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Compose the shared dark-mode toggle with this tab's own action so
      // both float in the bottom-right corner without overlapping.
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ThemeToggleFab(mini: true),
          const SizedBox(height: 12),
          const DownloadAppFab(mini: true),
          const SizedBox(height: 12),
          FloatingActionButton(
            onPressed: () => _showCreate(),
            child: const Icon(Icons.person_add),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _employees.isEmpty
              ? RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 220),
                      Center(child: Text('No employees found')),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.all(AppTheme.pad(context, 16)),
                    itemCount: _employees.length,
                    itemBuilder: (ctx, i) {
                      final e = _employees[i];
                      final isRevealed = _viewingUserId == e.id && _revealedPassword != null;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Padding(
                          padding: EdgeInsets.all(AppTheme.pad(context, 12)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: AppTheme.success.withValues(alpha: 0.1),
                                    child: Text(e.name[0].toUpperCase(),
                                      style: const TextStyle(color: AppTheme.success, fontWeight: FontWeight.bold)),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(e.name, style: TextStyle(fontWeight: FontWeight.w600, fontSize: AppTheme.fontSize(context, 15))),
                                        Text('${e.email} • ${e.permissions.length} permissions',
                                          style: TextStyle(fontSize: AppTheme.fontSize(context, 13), color: AppTheme.secondaryText(context))),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.vpn_key, size: 18),
                                    tooltip: 'Manage Permissions',
                                    onPressed: () => _showPermissions(e),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.danger),
                                    onPressed: () => _deleteEmployee(e),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: isRevealed ? AppTheme.passwordRevealedBg(context) : AppTheme.passwordHiddenBg(context),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(isRevealed ? Icons.visibility : Icons.visibility_off,
                                            size: 16, color: isRevealed ? AppTheme.success : AppTheme.mutedIcon(context)),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(isRevealed ? _revealedPassword! : '••••••••',
                                              style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w600,
                                                color: isRevealed ? AppTheme.textColor(context) : AppTheme.mutedIcon(context))),
                                          ),
                                          if (isRevealed)
                                            Text('$_countdown s',
                                              style: TextStyle(fontSize: AppTheme.fontSize(context, 12), color: AppTheme.warning, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton.icon(
                                    onPressed: isRevealed ? null : () => _viewPassword(e.id),
                                    icon: const Icon(Icons.key, size: 16),
                                    label: const Text('Show'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
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
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
              const SizedBox(height: 12),
              TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email'), keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 12),
              TextField(controller: passCtrl, decoration: const InputDecoration(labelText: 'Password'), obscureText: true),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.isEmpty || emailCtrl.text.isEmpty || passCtrl.text.isEmpty) return;
              try {
                await ApiService.createUser({'name': nameCtrl.text, 'email': emailCtrl.text, 'password': passCtrl.text});
                if (ctx.mounted) Navigator.pop(ctx);
                _load();
              } catch (e) {
                if (ctx.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
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
                  .map((p) => CheckboxListTile(
                        value: selected.contains(p),
                        title: Text(_permLabels[p] ?? p, style: TextStyle(fontSize: AppTheme.fontSize(context, 13))),
                        onChanged: (v) {
                          setDialogState(() {
                            if (v == true) { selected.add(p); } else { selected.remove(p); }
                          });
                        },
                      ))
                  .toList(),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
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
            Text('Email: ${employee.email}', style: TextStyle(fontSize: AppTheme.fontSize(context, 12), color: AppTheme.secondaryText(context))),
            const SizedBox(height: 12),
            const Text('Deleting this employee will:', style: TextStyle(fontWeight: FontWeight.w500)),
            const Text('• Remove all access to the system\n• Preserve transaction history (for audit)\n• Notify Admin of deletion'),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: selectedReason,
              isExpanded: true,
              items: reasons.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
              onChanged: (v) => selectedReason = v!,
              decoration: const InputDecoration(labelText: 'Reason'),
            ),
            const SizedBox(height: 8),
            Text('Request will be sent to Developer for approval',
              style: TextStyle(fontSize: AppTheme.fontSize(context, 12), color: AppTheme.warning, fontStyle: FontStyle.italic)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
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
}