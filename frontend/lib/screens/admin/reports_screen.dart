import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../utils/theme.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String _period = 'daily';
  Map<String, dynamic>? _profit;
  Map<String, dynamic>? _inventory;
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final profitRes = await ApiService.getProfitReport(period: _period);
      final invRes = await ApiService.getInventoryReport();
      setState(() {
        _profit = profitRes['report'];
        _inventory = invRes['inventory'];
        _loading = false;
      });
    } catch (e) { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final p = _profit ?? {};
    final inv = _inventory ?? {};

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Period selector
          Row(
            children: ['daily', 'monthly', 'yearly'].map((period) =>
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(period[0].toUpperCase() + period.substring(1)),
                  selected: _period == period,
                  onSelected: (_) { _period = period; _load(); },
                ),
              ),
            ).toList(),
          ),
          const SizedBox(height: 16),
          // Profit cards
          _reportCard('Revenue', '\$${(p['totalRevenue'] ?? 0).toStringAsFixed(2)}', AppTheme.success),
          _reportCard('Profit', '\$${(p['totalProfit'] ?? 0).toStringAsFixed(2)}', AppTheme.primary),
          _reportCard('Damage Loss', '-\$${(p['totalDamageLoss'] ?? 0).toStringAsFixed(2)}', AppTheme.danger),
          _reportCard('Net Profit', '\$${(p['netProfit'] ?? 0).toStringAsFixed(2)}', Colors.purple),
          const SizedBox(height: 20),
          // Inventory
          const Text('Inventory Overview', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _miniCard('Products', '${inv['totalProducts'] ?? 0}')),
              const SizedBox(width: 8),
              Expanded(child: _miniCard('Stock Value', '\$${(inv['totalStockValue'] ?? 0).toStringAsFixed(0)}')),
              const SizedBox(width: 8),
              Expanded(child: _miniCard('Low Stock', '${inv['lowStockCount'] ?? 0}', color: AppTheme.warning)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _reportCard(String label, String value, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _miniCard(String label, String value, {Color? color}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          ],
        ),
      ),
    );
  }
}
