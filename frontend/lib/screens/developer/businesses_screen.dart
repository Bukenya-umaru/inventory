import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/api_service.dart';
import '../../services/app_events.dart';
import '../../models/tenant.dart';
import '../../utils/theme.dart';
import '../../widgets/loading_button.dart';
import '../../widgets/compact_data_table.dart';
import '../../widgets/section_search_bar.dart';

class BusinessesScreen extends StatefulWidget {
  const BusinessesScreen({super.key});
  @override
  State<BusinessesScreen> createState() => _BusinessesScreenState();
}

class _BusinessesScreenState extends State<BusinessesScreen> {
  List<Tenant> _tenants = [];
  bool _loading = true;
  String _statusFilter = '';
  String _searchQuery = '';

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
      _searchQuery = globalQuery;
      _load();
    }
  }

  @override
  void dispose() {
    AppEvents.instance.unsubscribe(_onEvent);
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.getTenants(
        status: _statusFilter.isNotEmpty ? _statusFilter : null,
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
      );
      final list = (res['tenants'] as List)
          .map((t) => Tenant.fromJson(t))
          .toList();
      setState(() {
        _tenants = list;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Businesses',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _showCreateBusiness(),
                icon: const Icon(Icons.add_business, size: 18),
                label: const Text('Create Business'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                ),
              ),
            ],
          ),
        ),

        SectionSearchBar(
          hintText: 'Search businesses...',
          onSearch: (query) {
            _searchQuery = query;
            _load();
          },
        ),
        const SizedBox(height: 8),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: '', label: Text('All')),
                      ButtonSegment(value: 'active', label: Text('Active')),
                      ButtonSegment(
                        value: 'suspended',
                        label: Text('Suspended'),
                      ),
                      ButtonSegment(value: 'deleted', label: Text('Deleted')),
                    ],
                    selected: {_statusFilter},
                    onSelectionChanged: (v) {
                      _statusFilter = v.first;
                      _load();
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _tenants.isEmpty
              ? RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 220),
                      Center(child: Text('No businesses found')),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: CompactDataTable(
                      columns: const [
                        CompactTableColumn('Business', flex: 3),
                        CompactTableColumn('Owner', flex: 3),
                        CompactTableColumn('Type', flex: 2),
                        CompactTableColumn(
                          'Users',
                          flex: 1,
                          rightAligned: true,
                        ),
                        CompactTableColumn('Status', flex: 2),
                        CompactTableColumn(
                          'Actions',
                          flex: 3,
                          rightAligned: true,
                        ),
                      ],
                      rows: _tenants.map((tenant) {
                        final statusColor = switch (tenant.status) {
                          'active' => AppTheme.success,
                          'suspended' => AppTheme.warning,
                          _ => AppTheme.danger,
                        };
                        return CompactDataRow([
                          CompactDataTable.accent(context, tenant.businessName),
                          CompactDataTable.muted(context, tenant.ownerName),
                          CompactDataTable.cell(context, tenant.businessType),
                          CompactDataTable.cell(context, '${tenant.userCount}'),
                          CompactDataTable.chip(
                            context,
                            tenant.status,
                            statusColor,
                          ),
                          _TenantTableActions(
                            tenant: tenant,
                            onRefresh: _load,
                            onEdit: () => _showEditBusiness(tenant),
                          ),
                        ]);
                      }).toList(),
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  void _showCreateBusiness() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _CreateBusinessScreen(onCreated: _load),
      ),
    );
  }

  void _showEditBusiness(Tenant tenant) {
    final name = TextEditingController(text: tenant.businessName);
    final owner = TextEditingController(text: tenant.ownerName);
    final email = TextEditingController(text: tenant.email);
    final phone = TextEditingController(text: tenant.phoneNumber);
    final address = TextEditingController(text: tenant.address ?? '');
    final taxId = TextEditingController(text: tenant.taxId ?? '');
    var type = tenant.businessType;
    XFile? logoFile;
    Uint8List? logoBytes;
    const types = ['Retail', 'Wholesale', 'Manufacturing', 'Service', 'Other'];

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Edit Business'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () async {
                    final picked = await ImagePicker().pickImage(
                      source: ImageSource.gallery,
                      maxWidth: 512,
                      maxHeight: 512,
                    );
                    if (picked == null) return;
                    final bytes = await picked.readAsBytes();
                    setDialogState(() {
                      logoFile = picked;
                      logoBytes = bytes;
                    });
                  },
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppTheme.primary.withValues(alpha: 0.2),
                      ),
                    ),
                    child: logoBytes != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.memory(logoBytes!, fit: BoxFit.cover),
                          )
                        : tenant.businessLogo != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.network(
                              ApiService.fileUrl(tenant.businessLogo),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.add_a_photo_outlined,
                                color: AppTheme.primary,
                              ),
                            ),
                          )
                        : const Icon(
                            Icons.add_a_photo_outlined,
                            color: AppTheme.primary,
                          ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Click the logo to choose a new business logo',
                  style: TextStyle(
                    fontSize: AppTheme.fontSize(context, 11),
                    color: AppTheme.secondaryText(context),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Business Name'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: types.contains(type) ? type : types.first,
                  items: types
                      .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                      .toList(),
                  onChanged: (v) => setDialogState(() => type = v ?? type),
                  decoration: const InputDecoration(labelText: 'Business Type'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: owner,
                  decoration: const InputDecoration(labelText: 'Owner Name'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: email,
                  decoration: const InputDecoration(
                    labelText: 'Business Email',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: phone,
                  decoration: const InputDecoration(labelText: 'Phone Number'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: address,
                  decoration: const InputDecoration(labelText: 'Address'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: taxId,
                  decoration: const InputDecoration(labelText: 'Tax ID'),
                ),
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
                await ApiService.updateTenantWithLogo(
                  tenant.id,
                  {
                    'businessName': name.text.trim(),
                    'businessType': type,
                    'ownerName': owner.text.trim(),
                    'email': email.text.trim(),
                    'phoneNumber': phone.text.trim(),
                    'address': address.text.trim(),
                    'taxId': taxId.text.trim(),
                  },
                  logoBytes,
                  logoFile?.name,
                );
                if (dialogContext.mounted) Navigator.pop(dialogContext);
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

class _CreateBusinessScreen extends StatefulWidget {
  final VoidCallback onCreated;
  const _CreateBusinessScreen({required this.onCreated});

  @override
  State<_CreateBusinessScreen> createState() => _CreateBusinessScreenState();
}

class _CreateBusinessScreenState extends State<_CreateBusinessScreen> {
  final _formKey = GlobalKey<FormState>();
  final _businessNameCtrl = TextEditingController();
  final _ownerNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _taxIdCtrl = TextEditingController();
  String _businessType = 'Retail';
  bool _saving = false;
  XFile? _logoXFile;
  Uint8List? _logoBytes;

  final _types = ['Retail', 'Wholesale', 'Manufacturing', 'Service', 'Other'];

  final _categories = [
    'Electronics',
    'Clothing',
    'Food & Beverage',
    'Furniture',
    'Books',
    'Health & Beauty',
  ];
  List<String> _selectedCategories = [
    'Electronics',
    'Clothing',
    'Food & Beverage',
    'Furniture',
    'Books',
    'Health & Beauty',
  ];

  @override
  void dispose() {
    _businessNameCtrl.dispose();
    _ownerNameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _taxIdCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final data = {
        'businessName': _businessNameCtrl.text.trim(),
        'businessType': _businessType,
        'ownerName': _ownerNameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'password': _passwordCtrl.text,
        'phoneNumber': _phoneCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'taxId': _taxIdCtrl.text.trim(),
        'defaultCategories': _selectedCategories,
      };
      await ApiService.createTenantWithLogo(data, _logoBytes, _logoXFile?.name);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Business created successfully!')),
        );
        widget.onCreated();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
    );
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() {
        _logoXFile = picked;
        _logoBytes = bytes;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Business Account')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppTheme.dialogMaxWidth),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _sectionHeader('Business Information'),
                const SizedBox(height: 12),

                Center(
                  child: GestureDetector(
                    onTap: _pickLogo,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppTheme.primary.withValues(alpha: 0.2),
                        ),
                      ),
                      child: _logoBytes != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.memory(
                                _logoBytes!,
                                fit: BoxFit.cover,
                              ),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_a_photo_outlined,
                                  size: 28,
                                  color: AppTheme.primary,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Business\nLogo',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.primary,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _businessNameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Business Name *',
                    prefixIcon: Icon(Icons.business),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _businessType,
                  items: _types
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (v) => setState(() => _businessType = v!),
                  decoration: const InputDecoration(
                    labelText: 'Business Type',
                    prefixIcon: Icon(Icons.category),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number *',
                    prefixIcon: Icon(Icons.phone),
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _addressCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Address',
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _taxIdCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Tax ID',
                    prefixIcon: Icon(Icons.receipt_long_outlined),
                  ),
                ),
                const SizedBox(height: 24),

                _sectionHeader('Admin / Owner Information'),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _ownerNameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Owner Name *',
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Admin Email *',
                    prefixIcon: Icon(Icons.email),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Admin Password *',
                    prefixIcon: Icon(Icons.lock),
                    helperText: 'Password will be viewable by Developer',
                  ),
                  obscureText: true,
                  validator: (v) => v == null || v.length < 6
                      ? 'Password must be at least 6 characters'
                      : null,
                ),
                const SizedBox(height: 24),

                _sectionHeader('Default Categories'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: _categories.map((cat) {
                    final selected = _selectedCategories.contains(cat);
                    return FilterChip(
                      label: Text(cat),
                      selected: selected,
                      onSelected: (v) {
                        setState(() {
                          if (v) {
                            _selectedCategories.add(cat);
                          } else {
                            _selectedCategories.remove(cat);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 32),

                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _create,
                    child: _saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Create Business Account'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.primary,
          ),
        ),
        const Divider(),
      ],
    );
  }
}

class _TenantTableActions extends StatelessWidget {
  final Tenant tenant;
  final VoidCallback onRefresh;
  final VoidCallback onEdit;

  const _TenantTableActions({
    required this.tenant,
    required this.onRefresh,
    required this.onEdit,
  });

  Future<void> _changeStatus(BuildContext context) async {
    try {
      if (tenant.status == 'active') {
        await ApiService.suspendTenant(tenant.id, 'Developer action');
      } else if (tenant.status == 'suspended') {
        await ApiService.reactivateTenant(tenant.id);
      } else {
        return;
      }
      onRefresh();
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $error')));
      }
    }
  }

  Future<void> _delete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Business Account'),
        content: Text('Permanently delete "${tenant.businessName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ApiService.deleteTenant(tenant.id);
      onRefresh();
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $error')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (tenant.status == 'deleted') return const SizedBox.shrink();
    final isActive = tenant.status == 'active';
    return CompactDataTable.actions([
      CompactDataTable.actionIcon(
        icon: Icons.edit_outlined,
        color: AppTheme.blueBright(context),
        tooltip: 'Edit business',
        onTap: onEdit,
      ),
      CompactDataTable.actionIcon(
        icon: isActive ? Icons.pause : Icons.play_arrow,
        color: isActive ? AppTheme.warning : AppTheme.success,
        tooltip: isActive ? 'Suspend business' : 'Reactivate business',
        onTap: () => _changeStatus(context),
      ),
      CompactDataTable.actionIcon(
        icon: Icons.delete_outline,
        color: AppTheme.danger,
        tooltip: 'Delete business',
        onTap: () => _delete(context),
      ),
    ]);
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
                  backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                  child: Text(
                    tenant.businessName[0].toUpperCase(),
                    style: const TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tenant.businessName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        tenant.email,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.secondaryText(context),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    tenant.status,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _info(context, 'Owner', tenant.ownerName),
                const SizedBox(width: 16),
                _info(context, 'Type', tenant.businessType),
                const SizedBox(width: 16),
                _info(context, 'Users', '${tenant.userCount}'),
                const Spacer(),

                IconButton(
                  icon: const Icon(Icons.branding_watermark, size: 18),
                  tooltip: 'Manage Branding',
                  onPressed: () => _showBranding(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (tenant.status == 'active') ...[
                  TextButton.icon(
                    onPressed: () => _suspend(context),
                    icon: const Icon(
                      Icons.pause,
                      size: 16,
                      color: AppTheme.warning,
                    ),
                    label: const Text(
                      'Suspend',
                      style: TextStyle(color: AppTheme.warning),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _delete(context),
                    icon: const Icon(
                      Icons.delete_outline,
                      size: 16,
                      color: AppTheme.danger,
                    ),
                    label: const Text(
                      'Delete',
                      style: TextStyle(color: AppTheme.danger),
                    ),
                  ),
                ],
                if (tenant.status == 'suspended') ...[
                  TextButton.icon(
                    onPressed: () => _reactivate(),
                    icon: const Icon(
                      Icons.play_arrow,
                      size: 16,
                      color: AppTheme.success,
                    ),
                    label: const Text(
                      'Reactivate',
                      style: TextStyle(color: AppTheme.success),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _delete(context),
                    icon: const Icon(
                      Icons.delete_outline,
                      size: 16,
                      color: AppTheme.danger,
                    ),
                    label: const Text(
                      'Delete',
                      style: TextStyle(color: AppTheme.danger),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _info(BuildContext context, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: AppTheme.secondaryText(context),
          ),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  void _suspend(BuildContext context) {
    final reasons = [
      'Payment/Subscription Issue',
      'Business Owner Request',
      'Compliance Review',
      'Temporary Closure',
    ];
    String selected = reasons.first;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Suspend Business Account'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Suspending "${tenant.businessName}" will:'),
            const SizedBox(height: 8),
            const Text(
              '• Prevent all users from logging in\n'
              '• Block all sales and inventory activities\n'
              '• Preserve all data for reactivation\n'
              '• Notify the business owner',
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: selected,
              items: reasons
                  .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                  .toList(),
              onChanged: (v) => selected = v!,
              decoration: const InputDecoration(labelText: 'Reason'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          LoadingElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.warning),
            loadingChild: const Text('Saving...'),
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
    final confirmCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'Delete Business Account',
          style: TextStyle(color: AppTheme.danger),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '⚠ PERMANENT ACTION - IRREVERSIBLE',
              style: TextStyle(
                color: AppTheme.danger,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text('Deleting "${tenant.businessName}" will:'),
            const SizedBox(height: 8),
            const Text(
              '• Permanently remove ALL user accounts\n'
              '• Delete ALL products, categories, and inventory data\n'
              '• Remove ALL transaction and sales history\n'
              '• Delete ALL financial and profit data\n'
              '• This action CANNOT BE UNDONE',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmCtrl,
              decoration: const InputDecoration(
                labelText: 'Type "DELETE" to confirm',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          LoadingElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            loadingChild: const Text('Deleting...'),
            onPressed: () async {
              if (confirmCtrl.text != 'DELETE') return;
              await ApiService.deleteTenant(tenant.id);
              if (ctx.mounted) Navigator.pop(ctx);
              onRefresh();
            },
            child: const Text('Permanently Delete'),
          ),
        ],
      ),
    );
  }

  void _showBranding(BuildContext context) {
    final nameCtrl = TextEditingController(text: tenant.businessName);
    final phoneCtrl = TextEditingController(text: tenant.phoneNumber);
    final addressCtrl = TextEditingController(text: tenant.address);
    XFile? brandingXFile;
    Uint8List? brandingBytes;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Business Branding'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: GestureDetector(
                    onTap: () async {
                      final picker = ImagePicker();
                      final picked = await picker.pickImage(
                        source: ImageSource.gallery,
                        maxWidth: 512,
                        maxHeight: 512,
                      );
                      if (picked != null) {
                        final bytes = await picked.readAsBytes();
                        setDialogState(() {
                          brandingXFile = picked;
                          brandingBytes = bytes;
                        });
                      }
                    },
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppTheme.primary.withValues(alpha: 0.2),
                        ),
                      ),
                      child: brandingBytes != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.memory(
                                brandingBytes!,
                                fit: BoxFit.cover,
                              ),
                            )
                          : (tenant.businessLogo != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: Image.network(
                                      ApiService.fileUrl(tenant.businessLogo),
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.add_a_photo_outlined,
                                            size: 28,
                                            color: AppTheme.primary,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Change\nLogo',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: AppTheme.primary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.add_a_photo_outlined,
                                        size: 28,
                                        color: AppTheme.primary,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Business\nLogo',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppTheme.primary,
                                        ),
                                      ),
                                    ],
                                  )),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Business Name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  decoration: const InputDecoration(labelText: 'Phone Number'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: addressCtrl,
                  decoration: const InputDecoration(labelText: 'Address'),
                  maxLines: 2,
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
                await ApiService.updateBrandingWithLogo(
                  tenant.id,
                  {
                    'businessName': nameCtrl.text,
                    'phoneNumber': phoneCtrl.text,
                    'address': addressCtrl.text,
                  },
                  brandingBytes,
                  brandingXFile?.name,
                );
                if (ctx.mounted) Navigator.pop(ctx);
                onRefresh();
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
