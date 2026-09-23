import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/supplier.dart';
import '../services/api_service.dart';
import '../services/app_events.dart';
import '../services/auth_provider.dart';
import '../utils/theme.dart';

/// Search-and-select field for suppliers. Instead of typing supplier
/// details by hand, the user picks a supplier that already exists in the
/// system (managed under Company > Suppliers). Selecting one exposes its
/// full info via [Supplier] so callers can snapshot name/phone/email onto
/// the record being created.
class SupplierPicker extends StatefulWidget {
  final Supplier? selected;

  /// Called when the user picks a supplier (null = cleared).
  final ValueChanged<Supplier?> onChanged;

  /// Invoked when the user taps "Add new supplier" and lacks a way to do
  /// it inline — the host screen can navigate to Company > Suppliers.
  final VoidCallback? onAddNewRequested;

  const SupplierPicker({
    super.key,
    required this.selected,
    required this.onChanged,
    this.onAddNewRequested,
  });

  @override
  State<SupplierPicker> createState() => _SupplierPickerState();
}

class _SupplierPickerState extends State<SupplierPicker> {
  bool _canManage() {
    final user = context.read<AuthProvider>().user;
    return user?.isAdmin == true || user?.isDeveloper == true;
  }

  Future<void> _openSearch() async {
    final picked = await showModalBottomSheet<Supplier>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _SupplierSearchSheet(
        canManage: _canManage(),
        onAddNewRequested: widget.onAddNewRequested,
      ),
    );
    if (picked != null) widget.onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.selected;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (s == null)
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: _openSearch,
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'Supplier *',
                helperText: 'Search and select from your saved suppliers',
                filled: true,
                fillColor: Theme.of(context).scaffoldBackgroundColor,
                suffixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
              ),
              child: const Text('Search supplier...',
                  style: TextStyle(color: Colors.grey)),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.success.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: AppTheme.success.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    s.name.isNotEmpty ? s.name[0].toUpperCase() : '?',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600)),
                      if (s.phone != null && s.phone!.isNotEmpty)
                        Text(s.phone!,
                            style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.secondaryText(context))),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Change supplier',
                  icon: const Icon(Icons.swap_horiz, size: 18),
                  onPressed: _openSearch,
                ),
                IconButton(
                  tooltip: 'Clear supplier',
                  icon: Icon(Icons.close,
                      size: 18, color: AppTheme.secondaryText(context)),
                  onPressed: () => widget.onChanged(null),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _SupplierSearchSheet extends StatefulWidget {
  final bool canManage;
  final VoidCallback? onAddNewRequested;

  const _SupplierSearchSheet({
    required this.canManage,
    this.onAddNewRequested,
  });

  @override
  State<_SupplierSearchSheet> createState() => _SupplierSearchSheetState();
}

class _SupplierSearchSheetState extends State<_SupplierSearchSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<Supplier> _results = [];
  bool _loading = true;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _load();
    AppEvents.instance.subscribe(_onEvent);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    AppEvents.instance.unsubscribe(_onEvent);
    super.dispose();
  }

  void _onEvent(String event) {
    if (event == 'suppliers' && mounted) _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final res = await ApiService.getSuppliers(
          search: _searchCtrl.text.trim().isNotEmpty
              ? _searchCtrl.text.trim()
              : null);
      final list = (res['suppliers'] as List)
          .map((s) => Supplier.fromJson(Map<String, dynamic>.from(s)))
          .toList();
      if (!mounted) return;
      setState(() {
        _results = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _load);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('Select Supplier',
                          style: Theme.of(context).textTheme.titleMedium),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _searchCtrl,
                  autofocus: true,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Search by name, phone or email...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    filled: true,
                    fillColor: Theme.of(context).scaffoldBackgroundColor,
                  ),
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _results.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.business_outlined,
                                    size: 44,
                                    color: AppTheme.secondaryText(context)
                                        .withValues(alpha: 0.4)),
                                const SizedBox(height: 10),
                                Text('No suppliers found',
                                    style: TextStyle(
                                        fontSize: 14,
                                        color:
                                            AppTheme.secondaryText(context))),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(12),
                            itemCount: _results.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 6),
                            itemBuilder: (ctx, i) {
                              final s = _results[i];
                              return Card(
                                margin: EdgeInsets.zero,
                                child: ListTile(
                                  onTap: () => Navigator.pop(context, s),
                                  leading: CircleAvatar(
                                    backgroundColor:
                                        AppTheme.primary.withValues(alpha: 0.1),
                                    child: Text(
                                      s.name.isNotEmpty
                                          ? s.name[0].toUpperCase()
                                          : '?',
                                      style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.primary),
                                    ),
                                  ),
                                  title: Text(s.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600)),
                                  subtitle: (s.phone != null &&
                                              s.phone!.isNotEmpty) ||
                                          (s.contactPerson != null &&
                                              s.contactPerson!.isNotEmpty)
                                      ? Text(
                                          [
                                            if (s.contactPerson != null &&
                                                s.contactPerson!.isNotEmpty)
                                              s.contactPerson!,
                                            if (s.phone != null &&
                                                s.phone!.isNotEmpty)
                                              s.phone!,
                                          ].join(' • '),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: AppTheme.secondaryText(
                                                  context)),
                                        )
                                      : null,
                                  trailing: const Icon(Icons.check_circle_outline,
                                      size: 18),
                                ),
                              );
                            },
                          ),
              ),
              if (widget.canManage)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: () {
                        Navigator.pop(context); // close the search sheet
                        widget.onAddNewRequested?.call();
                      },
                      icon: const Icon(Icons.add_business, size: 18),
                      label: const Text('Supplier not in the list? Add it'),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
