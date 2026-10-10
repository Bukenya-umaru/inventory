import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../models/user.dart';
import '../../utils/theme.dart';
import '../../widgets/loading_button.dart';
import '../../widgets/section_search_bar.dart';
import '../../widgets/compact_data_table.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});
  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  List<User> _users = [];
  bool _loading = true;
  String _search = '';
  String _roleFilter = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.getUsers(
        role: _roleFilter.isNotEmpty ? _roleFilter : null,
        search: _search.isNotEmpty ? _search : null,
      );
      final list = (res['users'] as List).map((u) => User.fromJson(u)).toList();
      setState(() {
        _users = list;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<List<Map<String, dynamic>>> _getActiveTenants() async {
    final res = await ApiService.getTenants(status: 'active');
    return (res['tenants'] as List)
        .map((t) => Map<String, dynamic>.from(t))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(AppTheme.pad(context, 16)),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'All Users',
                  style: TextStyle(
                    fontSize: AppTheme.fontSize(context, 20),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.add_circle_outline),
                tooltip: 'Create Account',
                onSelected: (v) {
                  if (v == 'admin') _showCreateAdmin();
                  if (v == 'employee') _showCreateBackupEmployee();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'admin',
                    child: ListTile(
                      leading: Icon(Icons.admin_panel_settings),
                      title: Text('Create Admin'),
                      subtitle: Text('For a business'),
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'employee',
                    child: ListTile(
                      leading: Icon(Icons.person_add),
                      title: Text('Create Employee (Backup)'),
                      subtitle: Text('When Admin is unavailable'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        SectionSearchBar(
          hintText: 'Search users...',
          onSearch: (query) {
            _search = query;
            _load();
          },
        ),
        const SizedBox(height: 8),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: AppTheme.pad(context, 16)),
          child: Row(
            children: [
              _filterChip('All', ''),
              const SizedBox(width: 8),
              _filterChip('Admins', 'admin'),
              const SizedBox(width: 8),
              _filterChip('Employees', 'employee'),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _users.isEmpty
              ? RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 220),
                      Center(child: Text('No users found')),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppTheme.pad(context, 16),
                    ),
                    child: CompactDataTable(
                      columns: const [
                        CompactTableColumn('Name', flex: 3),
                        CompactTableColumn('Email', flex: 4),
                        CompactTableColumn('Role', flex: 2),
                        CompactTableColumn(
                          'Actions',
                          flex: 2,
                          rightAligned: true,
                        ),
                      ],
                      rows: _users.map((u) {
                        final roleColor = u.isDeveloper
                            ? const Color(0xFF30D8C0)
                            : u.isAdmin
                            ? AppTheme.primary
                            : AppTheme.success;
                        return CompactDataRow([
                          CompactDataTable.accent(context, u.name),
                          CompactDataTable.muted(context, u.email),
                          CompactDataTable.chip(context, u.role, roleColor),
                          u.role == 'developer'
                              ? const SizedBox.shrink()
                              : CompactDataTable.actions([
                                  CompactDataTable.actionIcon(
                                    icon: Icons.edit_outlined,
                                    color: AppTheme.blueBright(context),
                                    tooltip: 'Edit user',
                                    onTap: () => _showEditUser(u),
                                  ),
                                  if (u.isEmployee)
                                    CompactDataTable.actionIcon(
                                      icon: u.accountStatus == 'suspended'
                                          ? Icons.play_arrow
                                          : Icons.pause,
                                      color: u.accountStatus == 'suspended'
                                          ? AppTheme.success
                                          : AppTheme.warning,
                                      tooltip: u.accountStatus == 'suspended'
                                          ? 'Reactivate employee'
                                          : 'Suspend employee',
                                      onTap: () => _toggleEmployeeStatus(u),
                                    ),
                                  CompactDataTable.actionIcon(
                                    icon: Icons.delete_outline,
                                    color: AppTheme.danger,
                                    tooltip: 'Delete user',
                                    onTap: () => _deleteUser(context, u),
                                  ),
                                ]),
                        ]);
                      }).toList(),
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _filterChip(String label, String value) {
    final selected = _roleFilter == value;
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(fontSize: AppTheme.fontSize(context, 12)),
      ),
      selected: selected,
      onSelected: (_) {
        _roleFilter = value;
        _load();
      },
    );
  }

  void _showEditUser(User user) {
    final name = TextEditingController(text: user.name);
    final email = TextEditingController(text: user.email);
    final password = TextEditingController();
    final department = TextEditingController(text: user.department ?? '');
    final position = TextEditingController(text: user.position ?? '');
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Edit ${user.role == 'admin' ? 'Admin' : 'Employee'}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: email,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: password,
                decoration: const InputDecoration(
                  labelText: 'New Password',
                  helperText: 'Leave blank to keep the current password',
                ),
                obscureText: true,
              ),
              if (user.isEmployee) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: department,
                  decoration: const InputDecoration(labelText: 'Department'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: position,
                  decoration: const InputDecoration(labelText: 'Position'),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          LoadingElevatedButton(
            loadingChild: const Text('Saving...'),
            onPressed: () async {
              final data = <String, dynamic>{
                'name': name.text.trim(),
                'email': email.text.trim(),
                if (user.isEmployee) ...{
                  'department': department.text.trim(),
                  'position': position.text.trim(),
                },
              };
              if (password.text.isNotEmpty) data['password'] = password.text;
              await ApiService.updateUser(user.id, data);
              if (dialogContext.mounted) Navigator.pop(dialogContext);
              _load();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleEmployeeStatus(User user) async {
    if (user.accountStatus == 'suspended') {
      await ApiService.reactivateUser(user.id);
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
      await ApiService.suspendUser(user.id, reason: reason.text.trim());
      _load();
    }
  }

  void _showCreateAdmin() {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    String? selectedTenantId;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Create Admin Account'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Select Business:',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _getActiveTenants(),
                  builder: (ctx2, snap) {
                    if (snap.connectionState != ConnectionState.done)
                      return const CircularProgressIndicator();
                    if (!snap.hasData || snap.data!.isEmpty)
                      return const Text('No active businesses found');
                    final tenants = snap.data!;
                    return DropdownButtonFormField<String>(
                      initialValue: selectedTenantId,
                      isExpanded: true,
                      items: tenants
                          .map(
                            (t) => DropdownMenuItem<String>(
                              value: t['_id'] as String,
                              child: Text(t['businessName'] as String),
                            ),
                          )
                          .toList(),
                      onChanged: (v) =>
                          setDialogState(() => selectedTenantId = v),
                      decoration: const InputDecoration(labelText: 'Business'),
                    );
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Admin Name'),
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
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    helperText: 'Password will be viewable by Developer',
                  ),
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
                    passCtrl.text.isEmpty ||
                    selectedTenantId == null)
                  return;
                try {
                  await ApiService.createAdminAccount({
                    'name': nameCtrl.text,
                    'email': emailCtrl.text,
                    'password': passCtrl.text,
                    'tenantId': selectedTenantId,
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
              child: const Text('Create Admin'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateBackupEmployee() {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    String? selectedTenantId;
    String? selectedReason;
    final reasons = [
      'Admin Unavailable',
      'Admin Requested Assistance',
      'New Business Setup',
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Create Employee (Backup)'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.warning.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Backup Option - When Admin is unable or requests assistance',
                    style: TextStyle(
                      fontSize: AppTheme.fontSize(context, 12),
                      color: AppTheme.warning,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Select Business:',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _getActiveTenants(),
                  builder: (ctx2, snap) {
                    if (snap.connectionState != ConnectionState.done)
                      return const CircularProgressIndicator();
                    if (!snap.hasData || snap.data!.isEmpty)
                      return const Text('No active businesses found');
                    final tenants = snap.data!;
                    return DropdownButtonFormField<String>(
                      initialValue: selectedTenantId,
                      isExpanded: true,
                      items: tenants
                          .map(
                            (t) => DropdownMenuItem<String>(
                              value: t['_id'] as String,
                              child: Text(t['businessName'] as String),
                            ),
                          )
                          .toList(),
                      onChanged: (v) =>
                          setDialogState(() => selectedTenantId = v),
                      decoration: const InputDecoration(labelText: 'Business'),
                    );
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Employee Name'),
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
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    helperText:
                        'Password will be viewable by Admin and Developer',
                  ),
                  obscureText: true,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedReason,
                  isExpanded: true,
                  items: reasons
                      .map(
                        (r) =>
                            DropdownMenuItem<String>(value: r, child: Text(r)),
                      )
                      .toList(),
                  onChanged: (v) => setDialogState(() => selectedReason = v),
                  decoration: const InputDecoration(
                    labelText: 'Reason for Creation',
                  ),
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
              loadingChild: const Text('Saving...'),
              onPressed: () async {
                if (nameCtrl.text.isEmpty ||
                    emailCtrl.text.isEmpty ||
                    passCtrl.text.isEmpty ||
                    selectedTenantId == null)
                  return;
                try {
                  await ApiService.createUser({
                    'name': nameCtrl.text,
                    'email': emailCtrl.text,
                    'password': passCtrl.text,
                    'tenantId': selectedTenantId,
                    'backupReason': selectedReason,
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
              child: const Text('Create Employee'),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteUser(BuildContext context, User user) {
    final reasons = [
      'Employee Resigned/Left Company',
      'Employee Terminated',
      'Employee Requested Account Removal',
      'Admin Requested Deletion',
    ];
    String selectedReason = reasons.first;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete User Account'),
        content: StatefulBuilder(
          builder: (ctx, setDialogState) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('User: ${user.name}'),
              Text(
                'Email: ${user.email}',
                style: TextStyle(
                  fontSize: AppTheme.fontSize(context, 12),
                  color: AppTheme.secondaryText(context),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Deleting this user will:',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const Text(
                '• Remove all access to the system\n• Preserve transaction history (for audit)\n• Notify Admin of deletion',
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: selectedReason,
                isExpanded: true,
                items: reasons
                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                    .toList(),
                onChanged: (v) {
                  selectedReason = v!;
                  setDialogState(() {});
                },
                decoration: const InputDecoration(labelText: 'Reason'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () async {
              await ApiService.deleteUser(user.id, reason: selectedReason);
              if (ctx.mounted) Navigator.pop(ctx);
              _load();
            },
            child: const Text('Delete User'),
          ),
        ],
      ),
    );
  }
}
