import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/api_service.dart';
import '../../models/audit_log.dart';
import '../../utils/theme.dart';

class AuditLogsScreen extends StatefulWidget {
  const AuditLogsScreen({super.key});
  @override
  State<AuditLogsScreen> createState() => _AuditLogsScreenState();
}

class _AuditLogsScreenState extends State<AuditLogsScreen> {
  List<AuditLog> _logs = [];
  bool _loading = true;
  String _severityFilter = '';

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.getAuditLogs(severity: _severityFilter.isNotEmpty ? _severityFilter : null);
      final list = (res['logs'] as List).map((l) => AuditLog.fromJson(l)).toList();
      setState(() { _logs = list; _loading = false; });
    } catch (e) { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Expanded(child: Text('Audit Logs', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
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
                onChanged: (v) { _severityFilter = v ?? ''; _load(); },
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _logs.length,
                  itemBuilder: (ctx, i) {
                    final log = _logs[i];
                    final sevColor = switch (log.severity) {
                      'warning' => AppTheme.warning,
                      'error' => Colors.orange,
                      'critical' => AppTheme.danger,
                      _ => AppTheme.primary,
                    };
                    return Card(
                      margin: const EdgeInsets.only(bottom: 6),
                      child: ListTile(
                        leading: Container(
                          width: 4,
                          decoration: BoxDecoration(color: sevColor, borderRadius: BorderRadius.circular(2)),
                        ),
                        title: Text(log.eventType.replaceAll('_', ' ').toUpperCase(),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        subtitle: Text(log.action ?? '', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: sevColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                              child: Text(log.severity, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: sevColor)),
                            ),
                            const SizedBox(height: 2),
                            Text(DateFormat('MMM d, HH:mm').format(log.timestamp),
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
