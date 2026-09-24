import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/purchase.dart';
import '../../services/api_service.dart';
import '../../services/app_events.dart';
import '../../services/auth_provider.dart';
import '../../utils/currency.dart';
import '../../utils/theme.dart';
import '../../widgets/compact_data_table.dart';

class CreditsScreen extends StatefulWidget {
  const CreditsScreen({super.key});

  @override
  State<CreditsScreen> createState() => _CreditsScreenState();
}

class _CreditsScreenState extends State<CreditsScreen> {
  List<Purchase> _credits = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    AppEvents.instance.subscribe(_onEvent);
  }

  void _onEvent(String event) {
    if (mounted && (event == 'purchases' || event == 'credits')) _load();
  }

  @override
  void dispose() {
    AppEvents.instance.unsubscribe(_onEvent);
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final response = await ApiService.getPurchases(
        paymentMethod: 'credit',
        creditPaid: false,
      );
      final credits = (response['purchases'] as List)
          .map((item) => Purchase.fromJson(item))
          .toList();
      if (mounted) {
        setState(() {
          _credits = credits;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  double get _outstanding =>
      _credits.fold(0, (sum, purchase) => sum + purchase.totalCost);

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final canMarkPaid =
        user != null &&
        (user.isAdmin ||
            user.isDeveloper ||
            user.hasPermission('record_purchases'));

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
                      'Credits',
                      style: TextStyle(
                        fontSize: AppTheme.fontSize(context, 20),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${_credits.length} unpaid purchases • Outstanding: ${Currency.formatWhole(_outstanding)}',
                      style: TextStyle(
                        color: AppTheme.secondaryText(context),
                        fontSize: AppTheme.fontSize(context, 13),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh credits',
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _credits.isEmpty
              ? Center(
                  child: Text(
                    'No unpaid credit purchases',
                    style: TextStyle(color: AppTheme.secondaryText(context)),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: CompactDataTable(
                    columns: const [
                      CompactTableColumn('Date', flex: 2),
                      CompactTableColumn('Product', flex: 3),
                      CompactTableColumn('Supplier', flex: 2),
                      CompactTableColumn('Amount', flex: 2),
                      CompactTableColumn('Status', flex: 2),
                      CompactTableColumn(
                        'Actions',
                        flex: 2,
                        rightAligned: true,
                      ),
                    ],
                    rows: _credits.map((purchase) {
                      return CompactDataRow([
                        CompactDataTable.cell(
                          context,
                          DateFormat(
                            'd MMM yyyy',
                          ).format(purchase.purchaseDate.toLocal()),
                        ),
                        CompactDataTable.accent(
                          context,
                          purchase.productName ?? 'Unknown',
                        ),
                        CompactDataTable.muted(
                          context,
                          purchase.supplier?.isNotEmpty == true
                              ? purchase.supplier!
                              : '—',
                        ),
                        CompactDataTable.cell(
                          context,
                          Currency.formatWhole(purchase.totalCost),
                          weight: FontWeight.w600,
                        ),
                        CompactDataTable.chip(
                          context,
                          'Unpaid',
                          AppTheme.warningBright(context),
                        ),
                        canMarkPaid
                            ? CompactDataTable.actionIcon(
                                icon: Icons.check_circle_outline,
                                color: AppTheme.successBright(context),
                                tooltip: 'Mark as fully paid',
                                onTap: () => _markPaid(purchase),
                              )
                            : const SizedBox.shrink(),
                      ]);
                    }).toList(),
                  ),
                ),
        ),
      ],
    );
  }

  Future<void> _markPaid(Purchase purchase) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Mark Credit as Paid'),
        content: Text(
          'Mark ${Currency.formatWhole(purchase.totalCost)} owed for '
          '"${purchase.productName ?? 'this purchase'}" as fully paid?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Mark Paid'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ApiService.markPurchaseCreditPaid(purchase.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Credit marked as fully paid.'),
          backgroundColor: AppTheme.success,
        ),
      );
      AppEvents.instance.emit('credits');
      AppEvents.instance.emit('purchases');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          backgroundColor: AppTheme.danger,
        ),
      );
    }
  }
}
