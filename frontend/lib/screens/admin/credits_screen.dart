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
import '../../widgets/section_search_bar.dart';

class CreditsScreen extends StatefulWidget {
  const CreditsScreen({super.key});

  @override
  State<CreditsScreen> createState() => _CreditsScreenState();
}

class _CreditsScreenState extends State<CreditsScreen> {
  List<Purchase> _credits = [];
  bool _loading = true;
  bool _showAll = false;
  bool _showUnpaidOnly = false;
  bool _showPaidOnly = false;
  String _searchQuery = '';
  DateTime? _startDate;
  DateTime? _endDate;

  DateTime get _safeStart => _startDate ?? _today();
  DateTime get _safeEnd => _endDate ?? _today();

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

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
      String? startStr;
      String? endStr;
      if (!_showAll) {
        startStr = DateTime(
          _safeStart.year,
          _safeStart.month,
          _safeStart.day,
        ).toUtc().toIso8601String();
        endStr = DateTime(
          _safeEnd.year,
          _safeEnd.month,
          _safeEnd.day,
          23,
          59,
          59,
          999,
        ).toUtc().toIso8601String();
      }
      final response = await ApiService.getPurchases(
        startDate: startStr,
        endDate: endStr,
        status: 'approved',
        paymentMethod: 'credit',
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

  void _showToday() {
    final today = _today();
    setState(() {
      _showAll = false;
      _startDate = today;
      _endDate = today;
    });
    _load();
  }

  void _showAllCredits() {
    setState(() => _showAll = true);
    _load();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _safeStart : _safeEnd,
      firstDate: DateTime(2020),
      lastDate: _today(),
    );
    if (picked == null) return;
    setState(() {
      _showAll = false;
      if (isStart) {
        _startDate = picked;
        if (_safeEnd.isBefore(picked)) _endDate = picked;
      } else {
        _endDate = picked;
        if (_safeStart.isAfter(picked)) _startDate = picked;
      }
    });
    _load();
  }

  String get _filterLabel {
    if (_showAll) return 'All Credits';
    if (_safeStart == _safeEnd) {
      if (_safeStart == _today()) return "Today's Credits";
      if (_safeStart == _today().subtract(const Duration(days: 1))) {
        return "Yesterday's Credits";
      }
      return DateFormat('MMM d, yyyy').format(_safeStart);
    }
    return '${DateFormat('MMM d').format(_safeStart)} — '
        '${DateFormat('MMM d, yyyy').format(_safeEnd)}';
  }

  List<Purchase> get _visibleCredits {
    return _credits.where((purchase) {
      if (_showUnpaidOnly && purchase.creditPaid) return false;
      if (_showPaidOnly && !purchase.creditPaid) return false;
      return matchesSectionSearch(_searchQuery, [
        purchase.productName,
        purchase.supplier,
        purchase.supplierPhone,
        purchase.invoiceNumber,
        purchase.recordedByName,
        purchase.totalCost,
        purchase.creditPaid ? 'paid' : 'unpaid',
      ]);
    }).toList();
  }

  double get _outstanding => _visibleCredits
      .where((purchase) => !purchase.creditPaid)
      .fold(0, (sum, purchase) => sum + purchase.totalCost);

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final canMarkPaid =
        user != null &&
        (user.isAdmin ||
            user.isDeveloper ||
            user.hasPermission('approve_credits'));

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
                      '${_visibleCredits.length} ${_showUnpaidOnly
                          ? 'unpaid '
                          : _showPaidOnly
                          ? 'paid '
                          : ''}credit purchases • Outstanding: ${Currency.formatWhole(_outstanding)}',
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
        SectionSearchBar(
          hintText: 'Search credits...',
          onSearch: (query) => setState(() => _searchQuery = query),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: EdgeInsets.fromLTRB(
            AppTheme.pad(context, 16),
            0,
            AppTheme.pad(context, 16),
            4,
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterBtn(
                  label: 'Unpaid',
                  icon: Icons.pending_actions,
                  isActive: _showUnpaidOnly,
                  onTap: () => setState(() {
                    _showUnpaidOnly = !_showUnpaidOnly;
                    if (_showUnpaidOnly) _showPaidOnly = false;
                  }),
                ),
                const SizedBox(width: 6),
                _filterBtn(
                  label: 'Paid',
                  icon: Icons.check_circle_outline,
                  isActive: _showPaidOnly,
                  onTap: () => setState(() {
                    _showPaidOnly = !_showPaidOnly;
                    if (_showPaidOnly) _showUnpaidOnly = false;
                  }),
                ),
                const SizedBox(width: 6),
                _filterBtn(
                  label: 'Today',
                  icon: Icons.today,
                  isActive:
                      !_showAll &&
                      _safeStart == _safeEnd &&
                      _safeStart == _today(),
                  onTap: _showToday,
                ),
                const SizedBox(width: 6),
                _filterBtn(
                  label: 'All',
                  icon: Icons.all_inclusive,
                  isActive: _showAll,
                  onTap: _showAllCredits,
                ),
                const SizedBox(width: 6),
                _dateChip(
                  label: _showAll
                      ? 'Start date'
                      : DateFormat('MMM d, yyyy').format(_safeStart),
                  icon: Icons.calendar_today,
                  onTap: () => _pickDate(isStart: true),
                ),
                const SizedBox(width: 4),
                Text(
                  '—',
                  style: TextStyle(
                    color: AppTheme.secondaryText(context),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 4),
                _dateChip(
                  label: _showAll
                      ? 'End date'
                      : DateFormat('MMM d, yyyy').format(_safeEnd),
                  icon: Icons.calendar_month,
                  onTap: () => _pickDate(isStart: false),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            AppTheme.pad(context, 16),
            4,
            AppTheme.pad(context, 16),
            8,
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _filterLabel,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.secondaryText(context),
              ),
            ),
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _visibleCredits.isEmpty
              ? Center(
                  child: Text(
                    _showUnpaidOnly
                        ? 'No unpaid credit purchases'
                        : _showPaidOnly
                        ? 'No paid credit purchases'
                        : 'No credit purchases',
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
                    rows: _visibleCredits.map((purchase) {
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
                          purchase.creditPaid ? 'Paid' : 'Unpaid',
                          purchase.creditPaid
                              ? AppTheme.successBright(context)
                              : AppTheme.warningBright(context),
                        ),
                        canMarkPaid && !purchase.creditPaid
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

  Widget _filterBtn({
    required String label,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.primary : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive
                ? AppTheme.primary
                : Theme.of(context).dividerColor.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isActive ? Colors.white : AppTheme.secondaryText(context),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: isActive
                    ? Colors.white
                    : AppTheme.secondaryText(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateChip({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppTheme.secondaryText(context)),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.secondaryText(context),
              ),
            ),
          ],
        ),
      ),
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
