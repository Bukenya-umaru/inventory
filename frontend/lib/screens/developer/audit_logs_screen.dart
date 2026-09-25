import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../models/audit_log.dart';
import '../../utils/theme.dart';
import '../../widgets/compact_data_table.dart';

class AuditLogsScreen extends StatefulWidget {
  const AuditLogsScreen({super.key});
  @override
  State<AuditLogsScreen> createState() => _AuditLogsScreenState();
}

class _AuditLogsScreenState extends State<AuditLogsScreen> {
  List<AuditLog> _logs = [];
  bool _loading = true;
  String _severityFilter = '';
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.getAuditLogs(
        severity: _severityFilter.isNotEmpty ? _severityFilter : null,
        startDate: _startDate?.toIso8601String(),
        endDate: _endDate?.toIso8601String(),
      );
      final list = (res['logs'] as List)
          .map((l) => AuditLog.fromJson(l))
          .toList();
      setState(() {
        _logs = list;
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
                  'Audit Logs',
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
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _logs.isEmpty
              ? _emptyState()
              : Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppTheme.pad(context, 16),
                  ),
                  child: CompactDataTable(
                    columns: const [
                      CompactTableColumn('Event', flex: 3),
                      CompactTableColumn('Action', flex: 5),
                      CompactTableColumn('Severity', flex: 2),
                      CompactTableColumn('Date', flex: 2, rightAligned: true),
                    ],
                    rows: _logs.map((log) {
                      final sevColor = switch (log.severity) {
                        'warning' => AppTheme.warning,
                        'error' => Colors.orange,
                        'critical' => AppTheme.danger,
                        _ => AppTheme.primary,
                      };
                      return CompactDataRow([
                        CompactDataTable.cell(
                          context,
                          log.eventType.replaceAll('_', ' ').toUpperCase(),
                          weight: FontWeight.w600,
                        ),
                        CompactDataTable.muted(context, log.action ?? ''),
                        CompactDataTable.chip(context, log.severity, sevColor),
                        CompactDataTable.cell(
                          context,
                          DateFormat('MMM d').format(log.timestamp),
                        ),
                      ]);
                    }).toList(),
                  ),
                ),
        ),
      ],
    );
  }
}
