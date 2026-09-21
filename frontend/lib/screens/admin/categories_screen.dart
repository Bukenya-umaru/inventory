import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/app_events.dart';
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
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.getCategories();
      final list =
          (res['categories'] as List).map((c) => Category.fromJson(c)).toList();
      setState(() {
        _categories = list;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  static const List<List<Color>> _gradients = [
    [Color(0xFFE53935), Color(0xFFC62828)], 
    [Color(0xFF1E88E5), Color(0xFF1565C0)], 
    [Color(0xFF43A047), Color(0xFF2E7D32)], 
    [Color(0xFFFB8C00), Color(0xFFF57C00)], 
    [Color(0xFF8E24AA), Color(0xFF6A1B9A)], 
    [Color(0xFF00ACC1), Color(0xFF00838F)], 
    [Color(0xFFD81B60), Color(0xFFAD1457)], 
    [Color(0xFF5C6BC0), Color(0xFF3949AB)], 
    [Color(0xFF6D4C41), Color(0xFF4E342E)], 
    [Color(0xFF00897B), Color(0xFF00695C)], 
  ];

  List<Color> _cardGradient(int index) =>
      _gradients[index % _gradients.length];

  IconData _categoryIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('electronic') || lower.contains('device')) return Icons.devices;
    if (lower.contains('cloth') || lower.contains('fashion') || lower.contains('apparel')) return Icons.checkroom;
    if (lower.contains('food') || lower.contains('beverage') || lower.contains('grocery')) return Icons.restaurant;
    if (lower.contains('furniture') || lower.contains('home')) return Icons.chair;
    if (lower.contains('book') || lower.contains('stationery')) return Icons.menu_book;
    if (lower.contains('health') || lower.contains('beauty') || lower.contains('cosmetic')) return Icons.spa;
    if (lower.contains('sport') || lower.contains('fitness')) return Icons.sports_basketball;
    if (lower.contains('toy') || lower.contains('game')) return Icons.toys;
    if (lower.contains('auto') || lower.contains('car') || lower.contains('vehicle')) return Icons.directions_car;
    if (lower.contains('accessor')) return Icons.watch;
    if (lower.contains('general') || lower.contains('misc')) return Icons.category;
    return Icons.label;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmall = size.height < 600 || size.width < 400;
    final isWide = size.width >= 900;

    return Column(
      children: [

        Padding(
          padding: EdgeInsets.fromLTRB(
              isSmall ? 12 : AppTheme.pad(context, 16),
              isSmall ? 12 : AppTheme.pad(context, 16),
              isSmall ? 12 : AppTheme.pad(context, 16),
              isSmall ? 8 : AppTheme.pad(context, 8)),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Categories',
                        style: TextStyle(
                            fontSize: AppTheme.fontSize(context, isSmall ? 18 : 22),
                            fontWeight: FontWeight.bold)),
                    Text('${_categories.length} product groups',
                        style: TextStyle(
                            fontSize: AppTheme.fontSize(context, isSmall ? 11 : 13),
                            color: AppTheme.secondaryText(context))),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _showForm(),
                icon: const Icon(Icons.add),
                tooltip: 'Add Category',
              ),
            ],
          ),
        ),

        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _categories.isEmpty
                  ? RefreshIndicator(
                      onRefresh: _load,
                      child: LayoutBuilder(
                        builder: (context, constraints) => ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(height: constraints.maxHeight * 0.35),
                            _emptyState(),
                          ],
                        ),
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                            isSmall ? 10 : AppTheme.pad(context, 16),
                            isSmall ? 10 : AppTheme.pad(context, 12),
                            isSmall ? 10 : AppTheme.pad(context, 16),
                            80),
                        child: isWide ? _wideGrid(isSmall) : _mobileGrid(isSmall),
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF5C6BC0).withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.category_outlined,
                size: 56, color: const Color(0xFF5C6BC0).withValues(alpha: 0.4)),
          ),
          const SizedBox(height: 16),
          Text('No categories yet',
              style: TextStyle(
                  fontSize: AppTheme.fontSize(context, 18),
                  fontWeight: FontWeight.w600,              color: AppTheme.secondaryText(context))),
                  const SizedBox(height: 6),
                  Text('Create categories to organize your products',
              style: TextStyle(
                  fontSize: AppTheme.fontSize(context, 13),
                  color: AppTheme.secondaryText(context))),
        ],
      ),
    );
  }

  Widget _wideGrid(bool isSmall) {
    return GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.5,
      ),
      itemCount: _categories.length,
      itemBuilder: (ctx, i) => _categoryCard(_categories[i], i, isSmall),
    );
  }

  Widget _mobileGrid(bool isSmall) {
    final crossCount = isSmall ? 3 : 2;
    return GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossCount,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: isSmall ? 1.2 : 1.4,
      ),
      itemCount: _categories.length,
      itemBuilder: (ctx, i) => _categoryCard(_categories[i], i, isSmall),
    );
  }

  Widget _categoryCard(Category c, int index, bool isSmall) {
    final gradient = _cardGradient(index);
    final icon = _categoryIcon(c.name);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showForm(category: c),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            children: [

              Positioned(
                top: -18,
                right: -18,
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(icon, color: Colors.white, size: isSmall ? 16 : 18),
                        ),
                        PopupMenuButton<String>(
                          padding: EdgeInsets.zero,
                          icon: Icon(Icons.more_vert, color: Colors.white.withValues(alpha: 0.7), size: 16),
                          onSelected: (v) {
                            if (v == 'edit') _showForm(category: c);
                            if (v == 'delete') _delete(c);
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(value: 'edit', child: Text('Edit')),
                            const PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete', style: TextStyle(color: AppTheme.danger))),
                          ],
                        ),
                      ],
                    ),
                    const Spacer(),

                    Text(c.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: AppTheme.fontSize(context, isSmall ? 11 : 13),
                            color: Colors.white)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showForm({Category? category}) {
    final ctrl = TextEditingController(text: category?.name ?? '');
    final descCtrl = TextEditingController(text: category?.description ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF5C6BC0).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                  category != null ? Icons.edit : Icons.add,
                  color: const Color(0xFF5C6BC0),
                  size: 20),
            ),
            const SizedBox(width: 10),
            Text(category != null ? 'Edit Category' : 'Add Category',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ctrl,
                decoration: InputDecoration(
                  labelText: 'Category Name *',
                  filled: true,
                  fillColor: Theme.of(context).scaffoldBackgroundColor,
                ),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                decoration: InputDecoration(
                  labelText: 'Description (optional)',
                  filled: true,
                  fillColor: Theme.of(context).scaffoldBackgroundColor,
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (ctrl.text.trim().isEmpty) return;
              try {
                if (category != null) {
                  await ApiService.updateCategory(category.id, ctrl.text);
                } else {
                  await ApiService.createCategory(ctrl.text,
                      description: descCtrl.text.isNotEmpty ? descCtrl.text : null);
                }
                if (ctx.mounted) Navigator.pop(ctx);

                AppEvents.instance.emit('products');
                _load();
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(e.toString()),
                      backgroundColor: AppTheme.danger));
                }
              }
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
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirm == true) {
      await ApiService.deleteCategory(c.id);
      AppEvents.instance.emit('products');
      _load();
    }
  }
}