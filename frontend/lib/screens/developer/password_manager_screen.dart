import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../models/user.dart';
import '../../utils/theme.dart';

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

  @override
  void initState() { super.initState(); _load(); }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.getUsers();
      final list = (res['users'] as List).map((u) => User.fromJson(u)).toList();
      setState(() { _users = list; _loading = false; });
    } catch (e) { setState(() => _loading = false); }
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.warning.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            children: [
              Icon(Icons.lock, color: AppTheme.warning, size: 18),
              SizedBox(width: 8),
              Expanded(child: Text('All password views are logged for security.', style: TextStyle(fontSize: 13, color: AppTheme.warning))),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _users.length,
                  itemBuilder: (ctx, i) {
                    final u = _users[i];
                    final isRevealed = _viewingUserId == u.id && _revealedPassword != null;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: (u.isAdmin ? AppTheme.primary : AppTheme.success).withOpacity(0.1),
                                  child: Text(u.name[0].toUpperCase(),
                                    style: TextStyle(color: u.isAdmin ? AppTheme.primary : AppTheme.success, fontWeight: FontWeight.bold)),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(u.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                      Text(u.email, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: isRevealed ? Colors.green.shade50 : Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(isRevealed ? Icons.visibility : Icons.visibility_off,
                                          size: 16, color: isRevealed ? AppTheme.success : Colors.grey),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            isRevealed ? _revealedPassword! : '••••••••',
                                            style: TextStyle(
                                              fontFamily: 'monospace',
                                              fontWeight: FontWeight.w600,
                                              color: isRevealed ? Colors.black87 : Colors.grey,
                                            ),
                                          ),
                                        ),
                                        if (isRevealed)
                                          Text('$_countdown s',
                                            style: const TextStyle(fontSize: 12, color: AppTheme.warning, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton.icon(
                                  onPressed: isRevealed ? null : () => _viewPassword(u.id),
                                  icon: const Icon(Icons.key, size: 16),
                                  label: const Text('Show'),
                                ),
                              ],
                            ),
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
