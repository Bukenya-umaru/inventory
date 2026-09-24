import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/category.dart';
import '../../services/api_service.dart';
import '../../services/app_events.dart';
import '../../utils/currency.dart';
import '../../utils/theme.dart';
import '../../widgets/compact_data_table.dart';
import '../../widgets/loading_button.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  List<Map<String, dynamic>> _expenses = [];
  List<Category> _categories = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    AppEvents.instance.subscribe(_onEvent);
  }

  void _onEvent(String event) {
    if (!mounted) return;
    if (event == 'expenses') {
      _load();
    } else if (event == 'categories') {
      _loadCategories();
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
      final results = await Future.wait([
        ApiService.getExpenses(),
        _fetchExpenseCategories(),
      ]);
      final expenseResponse = results[0] as Map<String, dynamic>;
      final expenseData = (expenseResponse['expenses'] as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      final categoryData = results[1] as List<Category>;
      if (!mounted) return;
      setState(() {
        _expenses = expenseData;
        _categories = categoryData;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<List<Category>> _fetchExpenseCategories() async {
    final result = await ApiService.getCategories(type: 'expense');
    return (result['categories'] as List)
        .whereType<Map>()
        .map((c) => Category.fromJson(Map<String, dynamic>.from(c)))
        .where((c) => c.type == 'expense')
        .toList();
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await _fetchExpenseCategories();
      if (mounted) setState(() => _categories = categories);
    } catch (_) {
      // Keep the current list visible if a background refresh fails.
    }
  }

  double get _total => _expenses.fold(
    0,
    (sum, e) => sum + ((e['amount'] as num?)?.toDouble() ?? 0),
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(AppTheme.pad(context, 16)),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Expenses',
                      style: TextStyle(
                        fontSize: AppTheme.fontSize(context, 20),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${_expenses.length} records • Total: ${Currency.formatWhole(_total)}',
                      style: TextStyle(
                        color: AppTheme.secondaryText(context),
                        fontSize: AppTheme.fontSize(context, 13),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _showExpenseForm,
                icon: const Icon(Icons.add),
                tooltip: 'Record Expense',
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _expenses.isEmpty
              ? _emptyState()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        AppTheme.pad(context, 16),
                        0,
                        AppTheme.pad(context, 16),
                        80,
                      ),
                      child: _table(),
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _table() {
    final rows = _expenses.map((expense) {
      final category = expense['categoryId'];
      final categoryName = category is Map
          ? category['name']?.toString() ?? 'Unknown'
          : 'Unknown';
      final date = DateTime.tryParse(expense['expenseDate']?.toString() ?? '');
      return CompactDataRow([
        CompactDataTable.cell(
          context,
          date == null ? '-' : DateFormat('d MMM yyyy').format(date.toLocal()),
        ),
        CompactDataTable.accent(context, categoryName),
        CompactDataTable.cell(
          context,
          Currency.format((expense['amount'] as num?)?.toDouble() ?? 0),
        ),
        CompactDataTable.cell(
          context,
          expense['description']?.toString() ?? '-',
        ),
        CompactDataTable.cell(
          context,
          expense['paymentMethod']?.toString() ?? 'cash',
        ),
      ]);
    }).toList();
    return CompactDataTable(
      columns: const [
        CompactTableColumn('Date'),
        CompactTableColumn('Category'),
        CompactTableColumn('Amount'),
        CompactTableColumn('Description', flex: 3),
        CompactTableColumn('Payment'),
      ],
      rows: rows,
    );
  }

  Widget _emptyState() {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 120),
          Icon(
            Icons.payments_outlined,
            size: 58,
            color: AppTheme.primary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              _categories.isEmpty
                  ? 'Create an expense category first'
                  : 'No expenses recorded',
              style: TextStyle(color: AppTheme.secondaryText(context)),
            ),
          ),
        ],
      ),
    );
  }

  void _showExpenseForm() {
    final amountCtrl = TextEditingController();
    final descriptionCtrl = TextEditingController();
    String? categoryId;
    String paymentMethod = 'cash';

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Record Expense'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Expense Category *',
                  ),
                  initialValue: categoryId,
                  items: _categories
                      .map(
                        (c) =>
                            DropdownMenuItem(value: c.id, child: Text(c.name)),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setDialogState(() => categoryId = value),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Amount *'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Payment Method',
                  ),
                  initialValue: paymentMethod,
                  items: const [
                    DropdownMenuItem(value: 'cash', child: Text('Cash')),
                    DropdownMenuItem(value: 'credit', child: Text('Credit')),
                    DropdownMenuItem(
                      value: 'bank_transfer',
                      child: Text('Bank Transfer'),
                    ),
                    DropdownMenuItem(
                      value: 'mobile_money',
                      child: Text('Mobile Money'),
                    ),
                    DropdownMenuItem(value: 'other', child: Text('Other')),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => paymentMethod = value ?? 'cash'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descriptionCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'Data, transport, or other details',
                  ),
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
                final amount = double.tryParse(amountCtrl.text.trim());
                if (categoryId == null || amount == null || amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Select a category and enter a valid amount.',
                      ),
                      backgroundColor: AppTheme.danger,
                    ),
                  );
                  return;
                }
                await ApiService.createExpense({
                  'categoryId': categoryId,
                  'amount': amount,
                  'description': descriptionCtrl.text.trim(),
                  'paymentMethod': paymentMethod,
                });
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                AppEvents.instance.emit('expenses');
              },
              child: const Text('Record'),
            ),
          ],
        ),
      ),
    );
  }
}
