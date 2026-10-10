import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../services/app_events.dart';
import '../../models/audit_log.dart';
import '../../utils/theme.dart';
import '../../widgets/compact_data_table.dart';
import '../../widgets/section_search_bar.dart';

class AuditLogsScreen extends StatefulWidget {
  final bool systemAudit;

  const AuditLogsScreen({super.key, this.systemAudit = false});
  @override
  State<AuditLogsScreen> createState() => _AuditLogsScreenState();
}

class _AuditLogsScreenState extends State<AuditLogsScreen> {
  List<AuditLog> _logs = [];
  bool _loading = true;
  String _severityFilter = '';
  DateTime? _startDate;
  DateTime? _endDate;
  int _page = 1;
  int _pages = 1;
  int _total = 0;
  String _searchQuery = '';

  List<AuditLog> get _visibleLogs => _logs
      .where((log) => matchesSectionSearch(_searchQuery, [
          log.eventType,
          log.userName,
          log.userRole,
          log.action,
          log.businessName,
          ]))
      .toList();

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
      setState(() => _searchQuery = globalQuery);
      _load();
    }
  }

  @override
  void dispose() {
    AppEvents.instance.unsubscribe(_onEvent);
    super.dispose();
  }

  Future<void> _load({int page = 1}) async {
    setState(() => _loading = true);
    try {
      final severity = _severityFilter.isNotEmpty ? _severityFilter : null;
      final startDate = _startDate?.toIso8601String();
      final endDate = _endDate?.toIso8601String();
      final res = widget.systemAudit
          ? await ApiService.getAuditLogs(
              severity: severity,
              startDate: startDate,
              endDate: endDate,
              search: _searchQuery,
              page: page,
            )
          : await ApiService.getBusinessActivityLogs(
              severity: severity,
              startDate: startDate,
              endDate: endDate,
              search: _searchQuery,
              page: page,
            );
      final list = (res['logs'] as List)
          .map((l) => AuditLog.fromJson(l))
          .toList();
      final pagination = res['pagination'] as Map<String, dynamic>? ?? {};
      setState(() {
        _logs = list;
        _page = pagination['page'] ?? page;
        _pages = pagination['pages'] ?? 1;
        _total = pagination['total'] ?? list.length;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _pickDate({required bool start}) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: (start ? _startDate : _endDate) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (selected == null) return;
    setState(() {
      if (start) {
        _startDate = DateTime(selected.year, selected.month, selected.day);
        if (_endDate != null && _endDate!.isBefore(_startDate!)) {
          _endDate = DateTime(
            selected.year,
            selected.month,
            selected.day,
            23,
            59,
            59,
            999,
          );
        }
      } else {
        _endDate = DateTime(
          selected.year,
          selected.month,
          selected.day,
          23,
          59,
          59,
          999,
        );
        if (_startDate != null && _startDate!.isAfter(_endDate!)) {
          _startDate = DateTime(selected.year, selected.month, selected.day);
        }
      }
    });
    _load();
  }

  Widget _emptyState() {
    final hasDateFilter = _startDate != null || _endDate != null;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 120),
          const Icon(Icons.event_busy, size: 52, color: Colors.grey),
          const SizedBox(height: 12),
          Center(
            child: Text(
              hasDateFilter
                  ? 'No activity found for the selected date range.'
                  : 'No activity found.',
              style: TextStyle(color: AppTheme.secondaryText(context)),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(AppTheme.pad(context, 16)),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.systemAudit ? 'System Audit Logs' : 'Business Activity',
                  style: TextStyle(
                    fontSize: AppTheme.fontSize(context, 20),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              DropdownButton<String>(
                value: _severityFilter,
                hint: const Text('All Severity'),
                items: const [
                  DropdownMenuItem(value: '', child: Text('All')),
                  DropdownMenuItem(value: 'info', child: Text('Info')),
                  DropdownMenuItem(value: 'warning', child: Text('Warning')),
                  DropdownMenuItem(value: 'error', child: Text('Error')),
                  DropdownMenuItem(value: 'critical', child: Text('Critical')),
                ],
                onChanged: (v) {
                  _severityFilter = v ?? '';
                  _load();
                },
              ),
              IconButton(
                icon: const Icon(Icons.date_range),
                tooltip: 'Select date range',
                onPressed: () => _pickDate(start: true),
              ),
              IconButton(
                icon: const Icon(Icons.event),
                tooltip: 'Select end date',
                onPressed: () => _pickDate(start: false),
              ),
              if (_startDate != null || _endDate != null)
                IconButton(
                  icon: const Icon(Icons.clear),
                  tooltip: 'Clear dates',
                  onPressed: () {
                    setState(() {
                      _startDate = null;
                      _endDate = null;
                    });
                    _load();
                  },
                ),
            ],
          ),
        ),
        SectionSearchBar(
          hintText: 'Search activity...',
          onSearch: (query) {
            setState(() => _searchQuery = query);
            _load();
          },
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _visibleLogs.isEmpty
              ? _emptyState()
              : Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppTheme.pad(context, 16),
                  ),
                  child: CompactDataTable(
                    columns: const [
                      CompactTableColumn('Event', flex: 2),
                      CompactTableColumn('Who', flex: 2),
                      CompactTableColumn('Action', flex: 5),
                      CompactTableColumn('When', flex: 2, rightAligned: true),
                    ],
                    rows: _visibleLogs.map((log) {
                      return CompactDataRow([
                        CompactDataTable.cell(
                          context,
                          log.eventType.replaceAll('_', ' ').toUpperCase(),
                          weight: FontWeight.w600,
                        ),
                        CompactDataTable.cell(
                          context,
                          '${log.userName ?? 'System'}${log.userRole == null ? '' : ' (${log.userRole})'}',
                        ),
                        CompactDataTable.muted(context, log.action ?? ''),
                        CompactDataTable.cell(
                          context,
                          DateFormat('MMM d, HH:mm').format(log.timestamp),
                        ),
                      ]);
                    }).toList(),
                  ),
                ),
        ),
        if (!_loading && _logs.isNotEmpty)
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppTheme.pad(context, 16),
              vertical: 8,
            ),
            child: Row(
              children: [
                Text('$_total activities'),
                const Spacer(),
                IconButton(
                  tooltip: 'Previous page',
                  onPressed: _page > 1 ? () => _load(page: _page - 1) : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                Text('$_page / $_pages'),
                IconButton(
                  tooltip: 'Next page',
                  onPressed: _page < _pages ? () => _load(page: _page + 1) : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
