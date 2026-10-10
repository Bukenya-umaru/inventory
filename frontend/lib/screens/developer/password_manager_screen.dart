import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../services/app_events.dart';
import '../../models/user.dart';
import '../../utils/theme.dart';
import '../../widgets/compact_data_table.dart';

class PasswordManagerScreen extends StatefulWidget {
  const PasswordManagerScreen({super.key});
  @override
  State<PasswordManagerScreen> createState() => _PasswordManagerScreenState();
}

class _PasswordManagerScreenState extends State<PasswordManagerScreen> {
  List<User> _users = [];
  bool _loading = true;
  String? _viewingUserId;
  String? _revealedPassword;
  int _countdown = 0;
  Timer? _timer;
  String _search = '';

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
      _search = globalQuery;
      _load();
    }
  }

  @override
  void dispose() {
    AppEvents.instance.unsubscribe(_onEvent);
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.getUsers(
        search: _search.trim().isEmpty ? null : _search.trim(),
      );
      final list = (res['users'] as List).map((u) => User.fromJson(u)).toList();
      setState(() {
        _users = list;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _viewPassword(String userId) async {
    try {
      final res = await ApiService.viewPassword(userId);
      setState(() {
        _viewingUserId = userId;
        _revealedPassword = res['password'];
        _countdown = res['visibleFor'] ?? 30;
      });
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        setState(() {
          _countdown--;
          if (_countdown <= 0) {
            _revealedPassword = null;
            _viewingUserId = null;
            t.cancel();
          }
        });
      });
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          margin: EdgeInsets.all(AppTheme.pad(context, 16)),
          padding: EdgeInsets.all(AppTheme.pad(context, 12)),
          decoration: BoxDecoration(
            color: AppTheme.warning.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.lock, color: AppTheme.warning, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'All password views are logged for security.',
                  style: TextStyle(
                    fontSize: AppTheme.fontSize(context, 13),
                    color: AppTheme.warning,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppTheme.pad(context, 16),
                  ),
                  child: CompactDataTable(
                    columns: const [
                      CompactTableColumn('Name', flex: 3),
                      CompactTableColumn('Email', flex: 4),
                      CompactTableColumn('Password', flex: 3),
                      CompactTableColumn(
                        'Actions',
                        flex: 2,
                        rightAligned: true,
                      ),
                    ],
                    rows: _users.map((u) {
                      final isRevealed =
                          _viewingUserId == u.id && _revealedPassword != null;
                      return CompactDataRow([
                        CompactDataTable.accent(context, u.name),
                        CompactDataTable.muted(context, u.email),
                        CompactDataTable.cell(
                          context,
                          isRevealed
                              ? '$_revealedPassword ($_countdown s)'
                              : '••••••••',
                          color: isRevealed
                              ? AppTheme.success
                              : AppTheme.mutedIcon(context),
                          weight: FontWeight.w600,
                        ),
                        CompactDataTable.actionIcon(
                          icon: Icons.key,
                          color: AppTheme.warning,
                          tooltip: isRevealed
                              ? 'Password visible'
                              : 'Show password',
                          onTap: isRevealed ? null : () => _viewPassword(u.id),
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
