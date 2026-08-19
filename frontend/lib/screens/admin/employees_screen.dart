import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../models/user.dart';
import '../../utils/theme.dart';

const _allPermissions = [
  'manage_categories', 'create_products', 'edit_products', 'delete_products',
  'record_sales', 'record_purchases', 'record_damages', 'view_inventory',
  'view_transactions', 'view_profits', 'adjust_inventory', 'view_reports',
];

const _permLabels = {
  'manage_categories': 'Manage Categories', 'create_products': 'Create Products',
  'edit_products': 'Edit Products', 'delete_products': 'Delete Products',
  'record_sales': 'Record Sales', 'record_purchases': 'Record Purchases',
  'record_damages': 'Record Damages', 'view_inventory': 'View Inventory',
  'view_transactions': 'View Transactions', 'view_profits': 'View Profits',
  'adjust_inventory': 'Adjust Inventory', 'view_reports': 'View Reports',
};

class EmployeesScreen extends StatefulWidget {
  const EmployeesScreen({super.key});
  @override
  State<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends State<EmployeesScreen> {
  List<User> _employees = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.getUsers(role: 'employee');
      final list = (res['users'] as List).map((u) => User.fromJson(u)).toList();
      setState(() { _employees = list; _loading = false; });
    } catch (e) { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreate(),
        child: const Icon(Icons.person_add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _employees.length,
              itemBuilder: (ctx, i) {
                final e = _employees[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.success.withOpacity(0.1),
                      child: Text(e.name[0].toUpperCase(),
                        style: const TextStyle(color: AppTheme.success, fontWeight: FontWeight.bold)),
                    ),
                    title: Text(e.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('${e.email} • ${e.permissions.length} permissions'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.vpn_key, size: 18),
                          onPressed: () => _showPermissions(e),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.danger),
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Delete Employee'),
                                content: Text('Delete "${e.name}"?'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                  ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
                                    onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
                                ],
                              ),
                            );
                            if (confirm == true) { await ApiService.deleteUser(e.id); _load(); }
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
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
              TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 12),
              TextField(controller: passCtrl, decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (nameCtrl.text.isEmpty || emailCtrl.text.isEmpty || passCtrl.text.isEmpty) return;
              await ApiService.createUser({
                'name': nameCtrl.text, 'email': emailCtrl.text, 'password': passCtrl.text,
              });
              if (ctx.mounted) Navigator.pop(ctx);
              _load();
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
              children: _allPermissions.map((p) => CheckboxListTile(
                value: selected.contains(p),
                title: Text(_permLabels[p] ?? p, style: const TextStyle(fontSize: 13)),
                onChanged: (v) {
                  setDialogState(() {
                    if (v == true) selected.add(p);
                    else selected.remove(p);
                  });
                },
              )).toList(),
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
}
