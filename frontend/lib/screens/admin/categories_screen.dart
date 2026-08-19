import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../models/category.dart';
import '../../utils/theme.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});
  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  List<Category> _categories = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.getCategories();
      final list = (res['categories'] as List).map((c) => Category.fromJson(c)).toList();
      setState(() { _categories = list; _loading = false; });
    } catch (e) { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showForm(),
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _categories.isEmpty
              ? const Center(child: Text('No categories yet'))
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 2.5,
                  ),
                  itemCount: _categories.length,
                  itemBuilder: (ctx, i) {
                    final c = _categories[i];
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.label_outline, color: AppTheme.primary),
                        title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        trailing: PopupMenuButton(
                          itemBuilder: (_) => [
                            const PopupMenuItem(value: 'edit', child: Text('Edit')),
                            const PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: AppTheme.danger))),
                          ],
                          onSelected: (v) {
                            if (v == 'edit') _showForm(category: c);
                            if (v == 'delete') _delete(c);
                          },
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  void _showForm({Category? category}) {
    final ctrl = TextEditingController(text: category?.name ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(category != null ? 'Edit Category' : 'Add Category'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (category != null) {
                await ApiService.updateCategory(category.id, ctrl.text);
              } else {
                await ApiService.createCategory(ctrl.text);
              }
              if (ctx.mounted) Navigator.pop(ctx);
              _load();
            },
            child: Text(category != null ? 'Update' : 'Create'),
          ),
        ],
      ),
    );
  }

  Future<void> _delete(Category c) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Category'),
        content: Text('Delete "${c.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm == true) { await ApiService.deleteCategory(c.id); _load(); }
  }
}
