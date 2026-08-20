import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../models/user.dart';
import '../../utils/theme.dart';

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
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.getUsers(
        role: _roleFilter.isNotEmpty ? _roleFilter : null,
        search: _search.isNotEmpty ? _search : null,
      );
      final list = (res['users'] as List).map((u) => User.fromJson(u)).toList();
      setState(() { _users = list; _loading = false; });
    } catch (e) { setState(() => _loading = false); }
  }

  Future<List<Map<String, dynamic>>> _getActiveTenants() async {
    final res = await ApiService.getTenants(status: 'active');
    return (res['tenants'] as List).map((t) => Map<String, dynamic>.from(t)).toList();
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
                child: Text('All Users',
                    style: TextStyle(fontSize: AppTheme.fontSize(context, 20), fontWeight: FontWeight.bold)),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.add_circle_outline),
                tooltip: 'Create Account',
                onSelected: (v) {
                  if (v == 'admin') _showCreateAdmin();
                  if (v == 'employee') _showCreateBackupEmployee();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'admin',
                    child: ListTile(leading: Icon(Icons.admin_panel_settings), title: Text('Create Admin'), subtitle: Text('For a business'))),
                  const PopupMenuItem(value: 'employee',
                    child: ListTile(leading: Icon(Icons.person_add), title: Text('Create Employee (Backup)'), subtitle: Text('When Admin is unavailable'))),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: AppTheme.pad(context, 16)),
          child: TextField(
            decoration: const InputDecoration(hintText: 'Search users...', prefixIcon: Icon(Icons.search)),
            onChanged: (v) { _search = v; _load(); },
          ),
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
                  ? const Center(child: Text('No users found'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: EdgeInsets.symmetric(horizontal: AppTheme.pad(context, 16)),
                        itemCount: _users.length,
                        itemBuilder: (ctx, i) {
                          final u = _users[i];
                          final roleColor = u.isDeveloper
                              ? const Color(0xFF7C3AED)
                              : u.isAdmin ? AppTheme.primary : AppTheme.success;
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: roleColor.withValues(alpha: 0.1),
                                child: Text(u.name[0].toUpperCase(), style: TextStyle(color: roleColor, fontWeight: FontWeight.bold)),
                              ),
                              title: Text(u.name, style: TextStyle(fontWeight: FontWeight.w600, fontSize: AppTheme.fontSize(context, 15))),
                              subtitle: Text(u.email, style: TextStyle(fontSize: AppTheme.fontSize(context, 13), color: Colors.grey.shade500)),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: roleColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(u.role,
                                        style: TextStyle(fontSize: AppTheme.fontSize(context, 11), fontWeight: FontWeight.w600, color: roleColor)),
                                  ),
                                  if (u.role != 'developer')
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.danger),
                                      onPressed: () => _deleteUser(context, u),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _filterChip(String label, String value) {
    final selected = _roleFilter == value;
    return FilterChip(
      label: Text(label, style: TextStyle(fontSize: AppTheme.fontSize(context, 12))),
      selected: selected,
      onSelected: (_) { _roleFilter = value; _load(); },
    );
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
                const Text('Select Business:', style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _getActiveTenants(),
                  builder: (ctx2, snap) {
                    if (snap.connectionState != ConnectionState.done) return const CircularProgressIndicator();
                    if (!snap.hasData || snap.data!.isEmpty) return const Text('No active businesses found');
                    final tenants = snap.data!;
                    return DropdownButtonFormField<String>(
                      initialValue: selectedTenantId,
                      isExpanded: true,
                      items: tenants.map((t) => DropdownMenuItem<String>(
                        value: t['_id'] as String, child: Text(t['businessName'] as String))).toList(),
                      onChanged: (v) => setDialogState(() => selectedTenantId = v),
                      decoration: const InputDecoration(labelText: 'Business'),
                    );
                  },
                ),
                const SizedBox(height: 12),
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Admin Name')),
                const SizedBox(height: 12),
                TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email'), keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 12),
                TextField(controller: passCtrl, decoration: const InputDecoration(labelText: 'Password', helperText: 'Password will be viewable by Developer'), obscureText: true),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.isEmpty || emailCtrl.text.isEmpty || passCtrl.text.isEmpty || selectedTenantId == null) return;
                try {
                  await ApiService.createAdminAccount({'name': nameCtrl.text, 'email': emailCtrl.text, 'password': passCtrl.text, 'tenantId': selectedTenantId});
                  if (ctx.mounted) Navigator.pop(ctx);
                  _load();
                } catch (e) {
                  if (ctx.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
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
    final reasons = ['Admin Unavailable', 'Admin Requested Assistance', 'New Business Setup'];

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
                  decoration: BoxDecoration(color: AppTheme.warning.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
                  child: Text('Backup Option - When Admin is unable or requests assistance',
                    style: TextStyle(fontSize: AppTheme.fontSize(context, 12), color: AppTheme.warning)),
                ),
                const SizedBox(height: 12),
                const Text('Select Business:', style: TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _getActiveTenants(),
                  builder: (ctx2, snap) {
                    if (snap.connectionState != ConnectionState.done) return const CircularProgressIndicator();
                    if (!snap.hasData || snap.data!.isEmpty) return const Text('No active businesses found');
                    final tenants = snap.data!;
                    return DropdownButtonFormField<String>(
                      initialValue: selectedTenantId,
                      isExpanded: true,
                      items: tenants.map((t) => DropdownMenuItem<String>(
                        value: t['_id'] as String, child: Text(t['businessName'] as String))).toList(),
                      onChanged: (v) => setDialogState(() => selectedTenantId = v),
                      decoration: const InputDecoration(labelText: 'Business'),
                    );
                  },
                ),
                const SizedBox(height: 12),
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Employee Name')),
                const SizedBox(height: 12),
                TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email'), keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 12),
                TextField(controller: passCtrl, decoration: const InputDecoration(labelText: 'Password', helperText: 'Password will be viewable by Admin and Developer'), obscureText: true),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedReason,
                  isExpanded: true,
                  items: reasons.map((r) => DropdownMenuItem<String>(value: r, child: Text(r))).toList(),
                  onChanged: (v) => setDialogState(() => selectedReason = v),
                  decoration: const InputDecoration(labelText: 'Reason for Creation'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.isEmpty || emailCtrl.text.isEmpty || passCtrl.text.isEmpty || selectedTenantId == null) return;
                try {
                  await ApiService.createUser({
                    'name': nameCtrl.text, 'email': emailCtrl.text, 'password': passCtrl.text,
                    'tenantId': selectedTenantId, 'backupReason': selectedReason,
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                  _load();
                } catch (e) {
                  if (ctx.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
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
    final reasons = ['Employee Resigned/Left Company', 'Employee Terminated', 'Employee Requested Account Removal', 'Admin Requested Deletion'];
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
              Text('Email: ${user.email}', style: TextStyle(fontSize: AppTheme.fontSize(context, 12), color: Colors.grey.shade500)),
              const SizedBox(height: 12),
              const Text('Deleting this user will:', style: TextStyle(fontWeight: FontWeight.w500)),
              const Text('• Remove all access to the system\n• Preserve transaction history (for audit)\n• Notify Admin of deletion'),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: selectedReason,
                isExpanded: true,
                items: reasons.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                onChanged: (v) { selectedReason = v!; setDialogState(() {}); },
                decoration: const InputDecoration(labelText: 'Reason'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
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
