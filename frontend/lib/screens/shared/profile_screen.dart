import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user.dart';
import '../../services/api_service.dart';
import '../../services/auth_provider.dart';
import '../../utils/theme.dart';

/// Shared "My Profile" screen, opened from the settings (gear) menu.
/// Shows the signed-in user's account details and a change-password form.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _saving = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'developer':
        return 'Developer';
      case 'admin':
        return 'Admin';
      default:
        return 'Employee';
    }
  }

  IconData _roleIcon(String role) {
    switch (role) {
      case 'developer':
        return Icons.code;
      case 'admin':
        return Icons.admin_panel_settings;
      default:
        return Icons.badge;
    }
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'developer':
        return AppTheme.blueBright(context);
      case 'admin':
        return AppTheme.dashNavyColor(context);
      default:
        return AppTheme.successBright(context);
    }
  }

  Future<void> _savePassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final res = await ApiService.changePassword(
        _currentCtrl.text,
        _newCtrl.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Password changed successfully.'),
          backgroundColor: AppTheme.success,
        ),
      );
      _formKey.currentState!.reset();
      _currentCtrl.clear();
      _newCtrl.clear();
      _confirmCtrl.clear();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppTheme.danger),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Could not change password. Is the server running?',
          ),
          backgroundColor: AppTheme.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Info row inside the account details card.
  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppTheme.mutedIcon(context)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: AppTheme.fontSize(context, 11),
                    color: AppTheme.secondaryText(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: AppTheme.fontSize(context, 14),
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textColor(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _desktopProfileRow(String label, Widget field) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 160,
            child: Text(
              label,
              style: TextStyle(
                fontSize: AppTheme.fontSize(context, 13),
                fontWeight: FontWeight.w600,
                color: AppTheme.textColor(context),
              ),
            ),
          ),
          Expanded(child: field),
        ],
      ),
    );
  }

  InputDecoration _desktopInputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: AppTheme.cardColor(context),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: BorderSide(color: AppTheme.dividerColor(context)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(4),
        borderSide: BorderSide(color: AppTheme.dividerColor(context)),
      ),
    );
  }

  Widget _buildDesktopProfile(User user, String businessName, String initial) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(AppTheme.pad(context, 28)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1080),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          decoration: BoxDecoration(
            color: AppTheme.cardColor(context),
            border: Border.all(color: AppTheme.dividerColor(context)),
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: AppTheme.dividerColor(context)),
                    ),
                  ),
                  child: Text(
                    'Profile Setting',
                    style: TextStyle(
                      fontSize: AppTheme.fontSize(context, 16),
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textColor(context),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _desktopProfileRow(
                  'Full Name',
                  TextFormField(
                    initialValue: user.name,
                    readOnly: true,
                    decoration: _desktopInputDecoration('Full Name'),
                  ),
                ),
                _desktopProfileRow(
                  'Email Address',
                  TextFormField(
                    initialValue: user.email,
                    readOnly: true,
                    decoration: _desktopInputDecoration('Email Address'),
                  ),
                ),
                _desktopProfileRow(
                  'Business',
                  TextFormField(
                    initialValue: businessName,
                    readOnly: true,
                    decoration: _desktopInputDecoration('Business'),
                  ),
                ),
                _desktopProfileRow(
                  'Current Password',
                  TextFormField(
                    controller: _currentCtrl,
                    obscureText: _obscureCurrent,
                    decoration: _desktopInputDecoration('Current Password')
                        .copyWith(
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureCurrent
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            onPressed: () => setState(
                              () => _obscureCurrent = !_obscureCurrent,
                            ),
                          ),
                        ),
                    validator: (value) =>
                        (value == null || value.isEmpty) ? 'Required' : null,
                  ),
                ),
                _desktopProfileRow(
                  'New Password',
                  TextFormField(
                    controller: _newCtrl,
                    obscureText: _obscureNew,
                    decoration: _desktopInputDecoration('New Password')
                        .copyWith(
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureNew
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            onPressed: () =>
                                setState(() => _obscureNew = !_obscureNew),
                          ),
                        ),
                    validator: (value) => (value == null || value.length < 6)
                        ? 'At least 6 characters'
                        : null,
                  ),
                ),
                _desktopProfileRow(
                  'Confirm Password',
                  TextFormField(
                    controller: _confirmCtrl,
                    obscureText: _obscureConfirm,
                    decoration: _desktopInputDecoration('Confirm Password')
                        .copyWith(
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirm
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            onPressed: () => setState(
                              () => _obscureConfirm = !_obscureConfirm,
                            ),
                          ),
                        ),
                    validator: (value) => (value != _newCtrl.text)
                        ? 'Passwords do not match'
                        : null,
                  ),
                ),
                _desktopProfileRow(
                  'Preview',
                  Align(
                    alignment: Alignment.centerLeft,
                    child: CircleAvatar(
                      radius: 34,
                      backgroundColor: _roleColor(
                        user.role,
                      ).withValues(alpha: 0.12),
                      child: Text(
                        initial,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: _roleColor(user.role),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _savePassword,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(120, 42),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Save'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final branding = auth.branding;
    final isSmall = AppTheme.isPhoneScreen(context);

    if (user == null) {
      return const Scaffold(body: Center(child: Text('Not signed in.')));
    }

    final initial = user.name.isNotEmpty ? user.name[0].toUpperCase() : '?';

    return Scaffold(
      backgroundColor: AppTheme.canvasColor(context),
      appBar: AppBar(
        backgroundColor: AppTheme.appBarColor(context),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'My Profile',
          style: TextStyle(
            fontSize: AppTheme.fontSize(context, 18),
            fontWeight: FontWeight.w600,
            color: AppTheme.textColor(context),
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isSmall ? AppTheme.dialogMaxWidth : 1120,
          ),
          child: isSmall
              ? SingleChildScrollView(
                  padding: EdgeInsets.all(
                    isSmall ? 14 : AppTheme.pad(context, 20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ---- Account details card ----
                      Container(
                        padding: EdgeInsets.all(
                          isSmall ? 14 : AppTheme.pad(context, 18),
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.cardColor(context),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppTheme.dividerColor(context),
                          ),
                        ),
                        child: Column(
                          children: [
                            // Avatar + name header
                            Column(
                              children: [
                                CircleAvatar(
                                  radius: isSmall ? 32 : 38,
                                  backgroundColor: _roleColor(
                                    user.role,
                                  ).withValues(alpha: 0.12),
                                  child: Text(
                                    initial,
                                    style: TextStyle(
                                      fontSize: AppTheme.fontSize(
                                        context,
                                        isSmall ? 26 : 32,
                                      ),
                                      fontWeight: FontWeight.bold,
                                      color: _roleColor(user.role),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  user.name,
                                  style: TextStyle(
                                    fontSize: AppTheme.fontSize(context, 18),
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textColor(context),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _roleColor(
                                      user.role,
                                    ).withValues(alpha: 0.10),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _roleIcon(user.role),
                                        size: 13,
                                        color: _roleColor(user.role),
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        _roleLabel(user.role),
                                        style: TextStyle(
                                          fontSize: AppTheme.fontSize(
                                            context,
                                            12,
                                          ),
                                          fontWeight: FontWeight.w600,
                                          color: _roleColor(user.role),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Divider(color: AppTheme.dividerColor(context)),
                            const SizedBox(height: 4),
                            _infoRow(
                              Icons.person_outline,
                              'Full Name',
                              user.name,
                            ),
                            _infoRow(Icons.email_outlined, 'Email', user.email),
                            _infoRow(
                              Icons.storefront,
                              'Business',
                              branding?.businessName ?? '-',
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ---- Change password card ----
                      Container(
                        padding: EdgeInsets.all(
                          isSmall ? 14 : AppTheme.pad(context, 18),
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.cardColor(context),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppTheme.dividerColor(context),
                          ),
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.lock_outline,
                                    size: 18,
                                    color: AppTheme.dashNavyColor(context),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Change Password',
                                    style: TextStyle(
                                      fontSize: AppTheme.fontSize(context, 15),
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.textColor(context),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _currentCtrl,
                                obscureText: _obscureCurrent,
                                decoration: InputDecoration(
                                  labelText: 'Current Password',
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscureCurrent
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                    ),
                                    onPressed: () => setState(
                                      () => _obscureCurrent = !_obscureCurrent,
                                    ),
                                  ),
                                ),
                                validator: (v) => (v == null || v.isEmpty)
                                    ? 'Required'
                                    : null,
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _newCtrl,
                                obscureText: _obscureNew,
                                decoration: InputDecoration(
                                  labelText: 'New Password',
                                  prefixIcon: const Icon(Icons.lock_reset),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscureNew
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                    ),
                                    onPressed: () => setState(
                                      () => _obscureNew = !_obscureNew,
                                    ),
                                  ),
                                ),
                                validator: (v) => (v == null || v.length < 6)
                                    ? 'At least 6 characters'
                                    : null,
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _confirmCtrl,
                                obscureText: _obscureConfirm,
                                decoration: InputDecoration(
                                  labelText: 'Confirm New Password',
                                  prefixIcon: const Icon(Icons.lock_reset),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscureConfirm
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                    ),
                                    onPressed: () => setState(
                                      () => _obscureConfirm = !_obscureConfirm,
                                    ),
                                  ),
                                ),
                                validator: (v) => (v != _newCtrl.text)
                                    ? 'Passwords do not match'
                                    : null,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: _saving ? null : _savePassword,
                                icon: _saving
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.save_outlined),
                                label: Text(
                                  _saving ? 'Saving...' : 'Save Password',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : _buildDesktopProfile(
                  user,
                  branding?.businessName ?? '-',
                  initial,
                ),
        ),
      ),
    );
  }
}
