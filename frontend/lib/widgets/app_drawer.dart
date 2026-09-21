import 'package:flutter/material.dart';
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

/// Floating dark/light mode toggle, shown bottom-right on the login screen
/// and (by default) on every screen wrapped in [ResponsiveNavWrapper].
class ThemeToggleFab extends StatelessWidget {
  final bool mini;

  const ThemeToggleFab({super.key, this.mini = false});

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDark;
    return FloatingActionButton(
      mini: mini,
      tooltip: isDark ? 'Switch to light mode' : 'Switch to dark mode',
      onPressed: () => context.read<ThemeProvider>().toggle(),
      child: Icon(isDark ? Icons.light_mode : Icons.dark_mode,
          size: mini ? 20 : null),
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

  /// Set false when a tab hosts its own Scaffold with a FAB that already
  /// composes a [ThemeToggleFab] (e.g. the Employees tab), to avoid two
  /// toggles stacked in the same corner.
  final bool showThemeFab;

  const ResponsiveNavWrapper({
    super.key,
    required this.selectedIndex,
    required this.onItemTap,
    required this.items,
    required this.body,
    this.appBar,
    this.title,
    this.showThemeFab = true,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth >= kWideScreenBreakpoint;
    final fab = showThemeFab ? const ThemeToggleFab() : null;

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
                floatingActionButton: fab,
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
      floatingActionButton: fab,
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

}

class DrawerItem {
  final IconData icon;
  final String label;
  final Widget Function() builder;

  const DrawerItem(
      {required this.icon, required this.label, required this.builder});
}