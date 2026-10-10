import 'package:flutter/material.dart';
import '../../models/supplier.dart';
import '../../services/api_service.dart';
import '../../services/app_events.dart';
import '../../services/auth_provider.dart';
import 'package:provider/provider.dart';
import '../../utils/theme.dart';
import '../../widgets/compact_data_table.dart';
import '../../widgets/loading_button.dart';
import '../../utils/currency.dart';

class SuppliersScreen extends StatefulWidget {
  const SuppliersScreen({super.key});
  @override
  State<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends State<SuppliersScreen> {
  List<Supplier> _suppliers = [];
  bool _loading = true;
  String _search = '';

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
    final globalQuery = AppEvents.globalSearchQuery(event);
    if (globalQuery != null) {
      _search = globalQuery;
      _load();
    } else if (event == 'purchases' || event == 'suppliers') {
      _load();
    }
  }

  bool _canManage() {
    final user = context.read<AuthProvider>().user;
    return user?.isAdmin == true || user?.isDeveloper == true;
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.getSuppliers(
        search: _search.isNotEmpty ? _search : null,
      );
      final list = (res['suppliers'] as List)
          .map((s) => Supplier.fromJson(Map<String, dynamic>.from(s)))
          .toList();
      if (!mounted) return;
      setState(() {
        _suppliers = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSmall =
        MediaQuery.of(context).size.height < 600 ||
        MediaQuery.of(context).size.width < 400;
    final canManage = _canManage();

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(isSmall ? 12 : AppTheme.pad(context, 16)),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Suppliers',
                      style: TextStyle(
                        fontSize: AppTheme.fontSize(context, isSmall ? 18 : 22),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${_suppliers.length} companies in your network',
                      style: TextStyle(
                        fontSize: AppTheme.fontSize(context, isSmall ? 11 : 13),
                        color: AppTheme.secondaryText(context),
                      ),
                    ),
                  ],
                ),
              ),
              if (canManage)
                IconButton(
                  onPressed: () => _showForm(),
                  icon: const Icon(Icons.add),
                  tooltip: 'Add Supplier',
                ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            isSmall ? 12 : AppTheme.pad(context, 16),
            0,
            isSmall ? 12 : AppTheme.pad(context, 16),
            8,
          ),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        onChanged: (v) {
                          _search = v;
                          _load();
                        },
                        decoration: InputDecoration(
                          hintText: 'Search suppliers...',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          isDense: true,
                          filled: true,
                          fillColor: Theme.of(context).scaffoldBackgroundColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.search),
                      label: const Text('Search'),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.search),
                label: const Text('Search'),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _suppliers.isEmpty
              ? RefreshIndicator(
                  onRefresh: _load,
                  child: LayoutBuilder(
                    builder: (context, constraints) => ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(height: constraints.maxHeight * 0.3),
                        _emptyState(canManage),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      AppTheme.pad(context, 16),
                      4,
                      AppTheme.pad(context, 16),
                      12,
                    ),
                    child: _suppliersTable(canManage),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _emptyState(bool canManage) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.business_outlined,
              size: 56,
              color: AppTheme.primary.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No suppliers yet',
            style: TextStyle(
              fontSize: AppTheme.fontSize(context, 18),
              fontWeight: FontWeight.w600,
              color: AppTheme.secondaryText(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            canManage
                ? 'Add the companies you buy stock from, then pick them when adding products'
                : 'Suppliers added by the business owner will appear here',
            style: TextStyle(
              fontSize: AppTheme.fontSize(context, 13),
              color: AppTheme.secondaryText(context),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Compact table view for wide screens.
  Widget _suppliersTable(bool canManage) {
    final rows = <CompactDataRow>[];
    for (var i = 0; i < _suppliers.length; i++) {
      final s = _suppliers[i];
      rows.add(
        CompactDataRow([
          CompactDataTable.accent(context, s.name),
          CompactDataTable.muted(context, s.contactPerson ?? '—'),
          CompactDataTable.cell(context, s.phone ?? '—'),
          CompactDataTable.muted(context, s.email ?? '—'),
          CompactDataTable.cell(context, '${s.purchaseCount}'),
          CompactDataTable.cell(
            context,
            Currency.formatWhole(s.totalSpent),
            weight: FontWeight.w600,
          ),
          CompactDataTable.actions([
            CompactDataTable.actionIcon(
              icon: Icons.visibility_outlined,
              color: AppTheme.blueBright(context),
              tooltip: 'View details',
              onTap: () => _showDetails(s),
            ),
            if (canManage)
              CompactDataTable.actionIcon(
                icon: Icons.edit_outlined,
                color: AppTheme.warningBright(context),
                tooltip: 'Edit',
                onTap: () => _showForm(supplier: s),
              ),
          ]),
        ], onTap: () => _showDetails(s)),
      );
    }

    return CompactDataTable(
      columns: const [
        CompactTableColumn('Supplier Name', flex: 3),
        CompactTableColumn('Contact Person', flex: 2),
        CompactTableColumn('Phone', flex: 2),
        CompactTableColumn('Email', flex: 3),
        CompactTableColumn('Purchases', flex: 1),
        CompactTableColumn('Total Spent', flex: 2),
        CompactTableColumn('Actions', flex: 1, rightAligned: true),
      ],
      rows: rows,
    );
  }

  void _showDetails(Supplier s) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      s.name.isNotEmpty ? s.name[0].toUpperCase() : '?',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      s.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _detailRow(
                Icons.person_outline,
                'Contact person',
                s.contactPerson,
                'Not set',
              ),
              _detailRow(Icons.phone_outlined, 'Phone', s.phone, 'Not set'),
              _detailRow(Icons.email_outlined, 'Email', s.email, 'Not set'),
              _detailRow(
                Icons.location_on_outlined,
                'Address',
                s.address,
                'Not set',
              ),
              _detailRow(Icons.notes_outlined, 'Notes', s.notes, '—'),
              const Divider(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _statTile('${s.purchaseCount}', 'deliveries'),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _statTile(
                      Currency.formatWhole(s.totalSpent),
                      'total spent',
                    ),
                  ),
                ],
              ),
              if (_canManage()) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _showForm(supplier: s);
                        },
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text('Edit'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.danger,
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _delete(s);
                        },
                        icon: const Icon(Icons.delete_outline, size: 16),
                        label: const Text('Delete'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _statTile(String value, String label) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.secondaryText(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(
    IconData icon,
    String label,
    String? value,
    String fallback,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppTheme.secondaryText(context)),
          const SizedBox(width: 10),
          Text(
            '$label:',
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.secondaryText(context),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              (value == null || value.isEmpty) ? fallback : value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: (value == null || value.isEmpty)
                    ? AppTheme.secondaryText(context)
                    : AppTheme.textColor(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showForm({Supplier? supplier}) {
    final isEditing = supplier != null;
    final nameCtrl = TextEditingController(text: supplier?.name ?? '');
    final contactCtrl = TextEditingController(
      text: supplier?.contactPerson ?? '',
    );
    final phoneCtrl = TextEditingController(text: supplier?.phone ?? '');
    final emailCtrl = TextEditingController(text: supplier?.email ?? '');
    final addressCtrl = TextEditingController(text: supplier?.address ?? '');
    final notesCtrl = TextEditingController(text: supplier?.notes ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          isEditing ? 'Edit Supplier' : 'Add Supplier',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _field(nameCtrl, 'Supplier Name *'),
              const SizedBox(height: 12),
              _field(contactCtrl, 'Contact Person'),
              const SizedBox(height: 12),
              _field(phoneCtrl, 'Phone', keyboardType: TextInputType.phone),
              const SizedBox(height: 12),
              _field(
                emailCtrl,
                'Email',
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              _field(addressCtrl, 'Address'),
              const SizedBox(height: 12),
              _field(notesCtrl, 'Notes', maxLines: 2),
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
              if (nameCtrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Supplier name is required.'),
                    backgroundColor: AppTheme.danger,
                  ),
                );
                return;
              }
              try {
                final data = {
                  'name': nameCtrl.text.trim(),
                  'contactPerson': contactCtrl.text.trim().isNotEmpty
                      ? contactCtrl.text.trim()
                      : null,
                  'phone': phoneCtrl.text.trim().isNotEmpty
                      ? phoneCtrl.text.trim()
                      : null,
                  'email': emailCtrl.text.trim().isNotEmpty
                      ? emailCtrl.text.trim()
                      : null,
                  'address': addressCtrl.text.trim().isNotEmpty
                      ? addressCtrl.text.trim()
                      : null,
                  'notes': notesCtrl.text.trim().isNotEmpty
                      ? notesCtrl.text.trim()
                      : null,
                };
                if (isEditing) {
                  await ApiService.updateSupplier(supplier.id, data);
                } else {
                  await ApiService.createSupplier(data);
                }
                if (ctx.mounted) Navigator.pop(ctx);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      isEditing
                          ? 'Supplier updated.'
                          : 'Supplier added — you can now select it when adding stock.',
                    ),
                    backgroundColor: AppTheme.success,
                  ),
                );
                AppEvents.instance.emit('suppliers');
                _load();
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(e.toString()),
                      backgroundColor: AppTheme.danger,
                    ),
                  );
                }
              }
            },
            child: Text(isEditing ? 'Update' : 'Add'),
          ),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label, {
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Theme.of(context).scaffoldBackgroundColor,
      ),
    );
  }

  Future<void> _delete(Supplier s) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Supplier'),
        content: Text(
          'Delete "${s.name}"? Past stock records keep their supplier info for history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ApiService.deleteSupplier(s.id);
      AppEvents.instance.emit('suppliers');
      _load();
    }
  }
}
