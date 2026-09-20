import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../services/auth_provider.dart';
import '../services/api_service.dart';
import '../services/app_events.dart';
import '../services/activity_watcher.dart';
import '../services/theme_provider.dart';
import '../utils/theme.dart';
import '../screens/shared/activity_notifications_screen.dart';

const double kWideScreenBreakpoint = 900;

class AppDrawer extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemTap;
  final List<DrawerItem> items;

  const AppDrawer({
    super.key,
    required this.selectedIndex,
    required this.onItemTap,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmall = size.height < 600 || size.width < 400;

    return Drawer(
      width: size.width < 400 ? size.width * 0.82 : 260,
      backgroundColor: AppTheme.sidebarBg,
      child: _DrawerContent(
        selectedIndex: selectedIndex,
        onItemTap: (i) {
          onItemTap(i);
          Navigator.pop(context);
        },
        items: items,
        isSmall: isSmall,
      ),
    );
  }
}

class AppSidebar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemTap;
  final List<DrawerItem> items;

  const AppSidebar({
    super.key,
    required this.selectedIndex,
    required this.onItemTap,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppTheme.sidebarBg,
      child: SizedBox(
        width: 240,
        child: Material(
          type: MaterialType.transparency,
          child: _DrawerContent(
            selectedIndex: selectedIndex,
            onItemTap: onItemTap,
            items: items,
            isSmall: false,
          ),
        ),
      ),
    );
  }
}

class _DrawerContent extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemTap;
  final List<DrawerItem> items;
  final bool isSmall;

  const _DrawerContent({
    required this.selectedIndex,
    required this.onItemTap,
    required this.items,
    required this.isSmall,
  });

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final branding = auth.branding;

    return SafeArea(
      child: Column(
        children: [

          Container(
            width: double.infinity,
            padding: EdgeInsets.all(isSmall ? 14 : 20),
            decoration: const BoxDecoration(
              color: AppTheme.sidebarBg,
            ),
            child: Row(
              children: [
                if (branding?.businessLogo != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      ApiService.fileUrl(branding!.businessLogo),
                      height: isSmall ? 28 : 32,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.storefront, size: 28, color: Colors.white),
                    ),
                  )
                else
                  const Icon(Icons.storefront, size: 28, color: Colors.white),
                SizedBox(width: isSmall ? 8 : 10),
                Expanded(
                  child: Text(
                    branding?.businessName ?? 'Inventory',
                    softWrap: true,
                    style: TextStyle(
                        fontSize: AppTheme.fontSize(context, isSmall ? 15 : 17),
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: Container(
              color: AppTheme.sidebarBg,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  final isActive = selectedIndex == index;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => onItemTap(index),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isSmall ? 12 : 14,
                            vertical: isSmall ? 10 : 12,
                          ),
                          decoration: BoxDecoration(
                            color: isActive ? AppTheme.sidebarActive : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                item.icon,
                                color: isActive ? Colors.white : Colors.grey.shade400,
                                size: isSmall ? 18 : 20,
                              ),
                              SizedBox(width: isSmall ? 10 : 12),
                              Expanded(
                                child: Text(
                                  item.label,
                                  style: TextStyle(
                                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                                    color: isActive ? Colors.white : Colors.grey.shade400,
                                    fontSize: AppTheme.fontSize(context, isSmall ? 13 : 14),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          SizedBox(height: isSmall ? 8 : 12),
        ],
      ),
    );
  }
}

class ResponsiveNavWrapper extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemTap;
  final List<DrawerItem> items;
  final Widget body;
  final PreferredSizeWidget? appBar;
  final String? title;

  const ResponsiveNavWrapper({
    super.key,
    required this.selectedIndex,
    required this.onItemTap,
    required this.items,
    required this.body,
    this.appBar,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth >= kWideScreenBreakpoint;

    if (isWide) {

      return Scaffold(
        backgroundColor: AppTheme.surfaceColor(context),
        body: Row(
          children: [
            AppSidebar(
              selectedIndex: selectedIndex,
              onItemTap: onItemTap,
              items: items,
            ),
            Expanded(
              child: Scaffold(
                backgroundColor: AppTheme.surfaceColor(context),
                appBar: appBar ?? AppBar(
                  backgroundColor: AppTheme.appBarColor(context),
                  elevation: 0,
                  surfaceTintColor: Colors.transparent,
                  title: Row(
                    children: [
                      Text(title ?? '',
                        style: TextStyle(
                          fontSize: AppTheme.fontSize(context, 18),
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textColor(context))),
                    ],
                  ),
                  actions: [
                    const _NotificationBell(),
                    _SettingsMenu(),
                    const SizedBox(width: 8),
                  ],
                ),
                body: body,
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: appBar ?? AppBar(
        title: Text(title ?? ''),
        actions: [
          const _NotificationBell(),
          _SettingsMenu(),
          const SizedBox(width: 8),
        ],
      ),
      drawer: AppDrawer(
        selectedIndex: selectedIndex,
        onItemTap: onItemTap,
        items: items,
      ),
      body: body,
    );
  }
}

class _NotificationBell extends StatefulWidget {
  const _NotificationBell();

  @override
  State<_NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<_NotificationBell> {
  int _unread = 0;

  @override
  void initState() {
    super.initState();
    _fetchUnread();
    AppEvents.instance.subscribe(_onEvent);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final role = context.watch<AuthProvider>().user?.role;
    ActivityWatcher.instance.updateRole(role);
    if (role == 'admin' || role == 'employee') {
      ActivityWatcher.instance.start();
    }
  }

  @override
  void dispose() {
    AppEvents.instance.unsubscribe(_onEvent);
    super.dispose();
  }

  void _onEvent(String event) {
    if (!mounted) return;
    if (['sales', 'purchases', 'damages', 'products', 'categories'].contains(event)) {
      _fetchUnread();
    }
  }

  Future<void> _fetchUnread() async {
    try {
      final res = await ApiService.getActivity(limit: 1);
      if (mounted) setState(() => _unread = (res['unreadCount'] ?? 0) as int);
    } catch (_) {

    }
  }

  Future<void> _open() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ActivityNotificationsScreen()),
    );
    _fetchUnread(); 
    await ActivityWatcher.instance.resync(); 
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (auth.user?.role != 'admin' && auth.user?.role != 'employee') {
      return const SizedBox.shrink();
    }
    return Stack(
      children: [
        IconButton(
          icon: Icon(Icons.notifications_outlined, color: AppTheme.mutedIcon(context)),
          tooltip: 'Activity',
          onPressed: _open,
        ),
        if (_unread > 0)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              decoration: const BoxDecoration(
                color: AppTheme.danger,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                _unread > 99 ? '99+' : '$_unread',
                style: const TextStyle(
                    color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
              ),
            ),
          ),
      ],
    );
  }
}

class _SettingsMenu extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final themeProvider = context.watch<ThemeProvider>();

    return PopupMenuButton<String>(
      offset: const Offset(0, 36),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      icon: Icon(Icons.settings_outlined, color: AppTheme.mutedIcon(context), size: 22),
      onSelected: (value) {
        if (value == 'toggle_theme') {
          themeProvider.toggle();
        } else if (value == 'change_color') {
          _showColorPicker(context, themeProvider);
        } else if (value == 'update_branding') {
          _showBrandingDialog(context, auth);
        } else if (value == 'logout') {
          auth.logout();
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem<String>(
          value: 'toggle_theme',
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                themeProvider.isDark ? Icons.dark_mode : Icons.light_mode,
                size: 16,
                color: themeProvider.isDark ? Colors.amber : Colors.orange,
              ),
              const SizedBox(width: 8),
              Text(
                themeProvider.isDark ? 'Dark Mode' : 'Light Mode',
                style: TextStyle(
                  fontSize: AppTheme.fontSize(context, 13),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                themeProvider.isDark ? Icons.check_circle : Icons.check_circle_outline,
                size: 16,
                color: themeProvider.isDark ? Colors.amber : AppTheme.success,
              ),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'change_color',
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.palette_outlined, size: 16, color: themeProvider.accentColor),
              const SizedBox(width: 8),
              Text('Change Color',
                style: TextStyle(
                  fontSize: AppTheme.fontSize(context, 13),
                  fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              Container(
                width: 16, height: 16,
                decoration: BoxDecoration(
                  color: themeProvider.accentColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey.shade400, width: 1),
                ),
              ),
            ],
          ),
        ),
        if (auth.user?.role == 'admin')
          PopupMenuItem<String>(
            value: 'update_branding',
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.storefront_outlined, size: 16, color: AppTheme.primary),
                const SizedBox(width: 8),
                Text('Business Branding',
                  style: TextStyle(
                    fontSize: AppTheme.fontSize(context, 13),
                    fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        const PopupMenuDivider(height: 1),
        PopupMenuItem<String>(
          value: 'logout',
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              const Icon(Icons.logout, size: 16, color: AppTheme.danger),
              const SizedBox(width: 8),
              Text('Logout',
                style: TextStyle(
                  fontSize: AppTheme.fontSize(context, 13),
                  color: AppTheme.danger)),
            ],
          ),
        ),
      ],
    );
  }

  static const _presetColors = [
    Colors.red,
    Colors.pink,
    Colors.purple,
    Colors.deepPurple,
    Colors.indigo,
    Colors.blue,
    Colors.lightBlue,
    Colors.cyan,
    Colors.teal,
    Colors.green,
    Colors.lightGreen,
    Colors.lime,
    Colors.amber,
    Colors.orange,
    Colors.deepOrange,
    Colors.brown,
    Colors.blueGrey,
  ];

  void _showBrandingDialog(BuildContext context, AuthProvider auth) {
    final branding = auth.branding;
    Uint8List? pickedBytes;
    String? pickedName;
    bool saving = false;
    final nameCtrl = TextEditingController(text: branding?.businessName ?? '');
    final phoneCtrl = TextEditingController(text: branding?.phoneNumber ?? '');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Business Branding'),
          content: SizedBox(
            width: 320,
            child: ListView(
              shrinkWrap: true,
              children: [
                Center(
                  child: GestureDetector(
                    onTap: () async {
                      final picked = await ImagePicker().pickImage(
                          source: ImageSource.gallery,
                          maxWidth: 512,
                          maxHeight: 512);
                      if (picked == null) return;
                      final bytes = await picked.readAsBytes();
                      setDialogState(() {
                        pickedBytes = bytes;
                        pickedName = picked.name;
                      });
                    },
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16),
                        border:
                            Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
                      ),
                      child: pickedBytes != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child:
                                  Image.memory(pickedBytes!, fit: BoxFit.cover))
                          : (branding?.businessLogo != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Image.network(
                                    ApiService.fileUrl(branding!.businessLogo),
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(
                                        Icons.add_a_photo_outlined,
                                        size: 28,
                                        color: AppTheme.primary),
                                  ),
                                )
                              : const Icon(Icons.add_a_photo_outlined,
                                  size: 28, color: AppTheme.primary)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text('Tap logo to change',
                    style: TextStyle(
                        fontSize: AppTheme.fontSize(context, 12),
                        color: AppTheme.secondaryText(context))),
                ),
                const SizedBox(height: 16),
                TextField(
                    controller: nameCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Business Name')),
                const SizedBox(height: 12),
                TextField(
                    controller: phoneCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Phone Number')),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel')),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      setDialogState(() => saving = true);
                      try {
                        await ApiService.updateMyBrandingWithLogo({
                          'businessName': nameCtrl.text.trim(),
                          'phoneNumber': phoneCtrl.text.trim(),
                        }, pickedBytes, pickedName);
                        await auth.refreshBranding();
                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text('Branding updated.'),
                            backgroundColor: AppTheme.success));
                        }
                      } catch (e) {
                        if (ctx.mounted) setDialogState(() => saving = false);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('Failed to update branding: $e'),
                          backgroundColor: AppTheme.danger));
                      }
                    },
              child: saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save')),
          ],
        ),
      ),
    );
  }

  void _showColorPicker(BuildContext context, ThemeProvider themeProvider) {
    Color selected = themeProvider.accentColor;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Choose Accent Color'),
          content: SizedBox(
            width: 300,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [

                Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: selected,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'Selected',
                    style: TextStyle(
                      color: _contrastColor(selected),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _presetColors.map((c) {
                    final isSelected = c.value == selected.value;
                    return GestureDetector(
                      onTap: () => setDialogState(() => selected = c),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? Colors.white : Colors.grey.shade300,
                            width: isSelected ? 3 : 1,
                          ),
                          boxShadow: isSelected
                              ? [BoxShadow(color: c.withValues(alpha: 0.5), blurRadius: 6)]
                              : null,
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, size: 18, color: Colors.white)
                            : null,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                themeProvider.setAccentColor(selected);
                Navigator.pop(ctx);
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  static Color _contrastColor(Color c) {
    return c.computeLuminance() > 0.5 ? Colors.black : Colors.white;
  }
}

class DrawerItem {
  final IconData icon;
  final String label;
  final Widget Function() builder;

  const DrawerItem(
      {required this.icon, required this.label, required this.builder});
}