import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_provider.dart';
import '../models/audit_log.dart';

import '../services/api_service.dart';
import '../services/app_events.dart';
import '../services/activity_watcher.dart';
import '../services/theme_provider.dart';
import '../utils/theme.dart';
import '../screens/shared/activity_notifications_screen.dart';
import '../screens/shared/profile_screen.dart';

const double kWideScreenBreakpoint = 900;

/// A child entry under a parent [DrawerItem] (e.g. Transactions > History).
class DrawerChildItem {
  final IconData icon;
  final String label;
  const DrawerChildItem({required this.icon, required this.label});
}

class AppDrawer extends StatelessWidget {
  final int selectedIndex;
  final Function(int, {int? childIndex}) onItemTap;
  final List<DrawerItem> items;
  final bool darkSidebar;

  const AppDrawer({
    super.key,
    required this.selectedIndex,
    required this.onItemTap,
    required this.items,
    this.darkSidebar = false,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmall = size.height < 600 || size.width < 400;

    return Drawer(
      width: size.width < 400 ? size.width * 0.82 : 260,
      backgroundColor: darkSidebar
          ? const Color(0xFF181A1B)
          : AppTheme.sidebarColor(context),
      child: _DrawerContent(
        selectedIndex: selectedIndex,
        // Parent taps only toggle the branch open/closed (drawer stays open
        // so the user sees the tree expand); child and leaf taps navigate
        // and close the drawer.
        onItemTap: (i, {int? childIndex}) {
          onItemTap(i, childIndex: childIndex);
          if (childIndex != null || !items[i].hasChildren) {
            Navigator.pop(context);
          }
        },
        items: items,
        isSmall: isSmall,
        darkSidebar: darkSidebar,
      ),
    );
  }
}

class AppSidebar extends StatelessWidget {
  final int selectedIndex;
  final Function(int, {int? childIndex}) onItemTap;
  final List<DrawerItem> items;
  final bool darkSidebar;

  const AppSidebar({
    super.key,
    required this.selectedIndex,
    required this.onItemTap,
    required this.items,
    this.darkSidebar = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: darkSidebar
            ? const Color(0xFF181A1B)
            : AppTheme.sidebarColor(context),
        border: Border(
          right: BorderSide(
            color: darkSidebar
                ? const Color(0xFF292C2E)
                : AppTheme.dividerColor(context),
          ),
        ),
      ),
      child: SizedBox(
        width: 240,
        child: Material(
          type: MaterialType.transparency,
          child: _DrawerContent(
            selectedIndex: selectedIndex,
            onItemTap: onItemTap,
            items: items,
            isSmall: false,
            darkSidebar: darkSidebar,
          ),
        ),
      ),
    );
  }
}

/// Expandable tree row used for parents that have children
/// (e.g. Transactions with a History branch underneath).
class _ExpandableNavItem extends StatelessWidget {
  final DrawerItem item;
  final bool isActive;
  final bool isExpanded;
  final VoidCallback onToggle;
  final int? activeChildIndex;
  final ValueChanged<int> onChildTap;
  final bool isSmall;
  final bool darkSidebar;

  const _ExpandableNavItem({
    required this.item,
    required this.isActive,
    required this.isExpanded,
    required this.onToggle,
    required this.activeChildIndex,
    required this.onChildTap,
    required this.isSmall,
    required this.darkSidebar,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = darkSidebar
        ? const Color(0xFF1DBF73)
        : AppTheme.dashNavyColor(context);
    final inactiveColor = darkSidebar
        ? const Color(0xFFABB2B7)
        : AppTheme.secondaryText(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onToggle,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: isSmall ? 12 : 14,
                vertical: isSmall ? 10 : 12,
              ),
              decoration: BoxDecoration(
                color: isActive
                    ? darkSidebar
                          ? const Color(0xFF073A2C)
                          : AppTheme.sidebarActive.withValues(alpha: 0.16)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    item.icon,
                    color: isActive ? activeColor : inactiveColor,
                    size: isSmall ? 18 : 20,
                  ),
                  SizedBox(width: isSmall ? 10 : 12),
                  Expanded(
                    child: Text(
                      item.label,
                      style: TextStyle(
                        fontWeight: isActive
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: isActive ? activeColor : inactiveColor,
                        fontSize: AppTheme.fontSize(context, isSmall ? 13 : 14),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  AnimatedRotation(
                    turns: isExpanded ? 0.25 : 0,
                    duration: const Duration(milliseconds: 150),
                    child: Icon(
                      Icons.expand_more,
                      size: isSmall ? 16 : 18,
                      color: isActive ? activeColor : inactiveColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Branch children, indented under the parent.
        AnimatedCrossFade(
          firstChild: const SizedBox(width: double.infinity, height: 0),
          secondChild: Padding(
            padding: EdgeInsets.only(left: isSmall ? 18 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var ci = 0; ci < item.children!.length; ci++)
                  _BranchChild(
                    child: item.children![ci],
                    isActive: activeChildIndex == ci && isActive,
                    onTap: () => onChildTap(ci),
                    isSmall: isSmall,
                    darkSidebar: darkSidebar,
                  ),
              ],
            ),
          ),
          crossFadeState: isExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 150),
          sizeCurve: Curves.easeOut,
        ),
      ],
    );
  }
}

/// Single tree branch row (the nested "History" entry).
class _BranchChild extends StatelessWidget {
  final DrawerChildItem child;
  final bool isActive;
  final VoidCallback onTap;
  final bool isSmall;
  final bool darkSidebar;

  const _BranchChild({
    required this.child,
    required this.isActive,
    required this.onTap,
    required this.isSmall,
    required this.darkSidebar,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive
        ? darkSidebar
              ? const Color(0xFF1DBF73)
              : AppTheme.dashNavyColor(context)
        : darkSidebar
        ? const Color(0xFFABB2B7)
        : AppTheme.secondaryText(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isSmall ? 10 : 12,
            vertical: isSmall ? 8 : 9,
          ),
          decoration: BoxDecoration(
            color: isActive
                ? darkSidebar
                      ? const Color(0xFF073A2C)
                      : AppTheme.sidebarActive.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              // Tree branch line connecting the child to its parent.
              Container(
                width: 10,
                height: 1,
                color: darkSidebar
                    ? const Color(0xFF3C4144)
                    : AppTheme.borderColor(context),
              ),
              const SizedBox(width: 6),
              Icon(child.icon, size: isSmall ? 15 : 16, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  child.label,
                  style: TextStyle(
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                    color: color,
                    fontSize: AppTheme.fontSize(context, isSmall ? 12 : 13),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DrawerContent extends StatelessWidget {
  final int selectedIndex;
  final Function(int, {int? childIndex}) onItemTap;
  final List<DrawerItem> items;
  final bool isSmall;
  final bool darkSidebar;

  const _DrawerContent({
    required this.selectedIndex,
    required this.onItemTap,
    required this.items,
    required this.isSmall,
    required this.darkSidebar,
  });

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final branding = auth.branding;

    return SafeArea(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(isSmall ? 14 : 20),
            child: Row(
              children: [
                if (branding?.businessLogo != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      ApiService.fileUrl(branding!.businessLogo),
                      height: isSmall ? 28 : 32,
                      errorBuilder: (_, _, _) => Icon(
                        Icons.storefront,
                        size: 28,
                        color: darkSidebar
                            ? const Color(0xFF1DBF73)
                            : AppTheme.dashNavyColor(context),
                      ),
                    ),
                  )
                else
                  Icon(
                    Icons.storefront,
                    size: 28,
                    color: darkSidebar
                        ? const Color(0xFF1DBF73)
                        : AppTheme.dashNavyColor(context),
                  ),
                SizedBox(width: isSmall ? 8 : 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        branding?.businessName ?? 'Inventory',
                        softWrap: true,
                        style: TextStyle(
                          fontSize: AppTheme.fontSize(
                            context,
                            isSmall ? 15 : 17,
                          ),
                          fontWeight: FontWeight.bold,
                          color: darkSidebar
                              ? Colors.white
                              : AppTheme.dashNavyColor(context),
                        ),
                      ),
                      if (darkSidebar)
                        const Text(
                          'Admin Panel',
                          style: TextStyle(
                            color: Color(0xFF9AA2A6),
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: Container(
              color: darkSidebar
                  ? const Color(0xFF181A1B)
                  : AppTheme.sidebarColor(context),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  final isActive = selectedIndex == index;

                  // Parents with children render as an expandable tree
                  // branch instead of a plain nav row.
                  if (item.hasChildren) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: _ExpandableNavItem(
                        item: item,
                        isActive: isActive,
                        isExpanded: item.initiallyExpanded ?? isActive,
                        onToggle: () => onItemTap(index),
                        activeChildIndex: item.activeChildIndex,
                        onChildTap: (ci) => onItemTap(index, childIndex: ci),
                        isSmall: isSmall,
                        darkSidebar: darkSidebar,
                      ),
                    );
                  }

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
                            color: isActive
                                ? darkSidebar
                                      ? const Color(0xFF073A2C)
                                      : AppTheme.sidebarActive.withValues(
                                          alpha: 0.16,
                                        )
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                item.icon,
                                color: isActive
                                    ? darkSidebar
                                          ? const Color(0xFF1DBF73)
                                          : AppTheme.dashNavyColor(context)
                                    : darkSidebar
                                    ? const Color(0xFFABB2B7)
                                    : AppTheme.mutedIcon(context),
                                size: isSmall ? 18 : 20,
                              ),
                              SizedBox(width: isSmall ? 10 : 12),
                              Expanded(
                                child: Text(
                                  item.label,
                                  style: TextStyle(
                                    fontWeight: isActive
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                    color: isActive
                                        ? darkSidebar
                                              ? const Color(0xFF1DBF73)
                                              : AppTheme.dashNavyColor(context)
                                        : darkSidebar
                                        ? const Color(0xFFABB2B7)
                                        : AppTheme.secondaryText(context),
                                    fontSize: AppTheme.fontSize(
                                      context,
                                      isSmall ? 13 : 14,
                                    ),
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
      // No hero: several FABs share this route (IndexedStack keeps every tab
      // alive), so the default hero tag would collide.
      heroTag: null,
      mini: mini,
      tooltip: isDark ? 'Switch to light mode' : 'Switch to dark mode',
      onPressed: () => context.read<ThemeProvider>().toggle(),
      child: Icon(
        isDark ? Icons.light_mode : Icons.dark_mode,
        size: mini ? 20 : null,
      ),
    );
  }
}

class ResponsiveNavWrapper extends StatelessWidget {
  final int selectedIndex;
  final Function(int, {int? childIndex}) onItemTap;
  final List<DrawerItem> items;
  final Widget body;
  final PreferredSizeWidget? appBar;

  /// Set false when a tab hosts its own Scaffold with a FAB that already
  /// composes a [ThemeToggleFab] (e.g. the Employees tab), to avoid two
  /// toggles stacked in the same corner.
  final bool showThemeFab;
  final bool darkSidebar;

  const ResponsiveNavWrapper({
    super.key,
    required this.selectedIndex,
    required this.onItemTap,
    required this.items,
    required this.body,
    this.appBar,
    this.showThemeFab = true,
    this.darkSidebar = false,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth >= kWideScreenBreakpoint;
    // Theme toggle bottom-right on every screen. Tabs with showThemeFab=false
    // manage their own corner (e.g. the Employees tab).
    final fab = showThemeFab ? const ThemeToggleFab() : null;

    if (isWide) {
      return Scaffold(
        backgroundColor: AppTheme.canvasColor(context),
        body: Row(
          children: [
            AppSidebar(
              selectedIndex: selectedIndex,
              onItemTap: onItemTap,
              items: items,
              darkSidebar: darkSidebar,
            ),
            Expanded(
              child: Scaffold(
                backgroundColor: AppTheme.canvasColor(context),
                floatingActionButton: fab,
                appBar:
                    appBar ??
                    AppBar(
                      backgroundColor: AppTheme.appBarColor(context),
                      elevation: 0,
                      surfaceTintColor: Colors.transparent,
                      title: _HeaderSearchField(width: _searchWidth(context)),
                      actions: [
                        _NotificationBell(
                          onActivitySelected: (log) =>
                              _openActivityLocation(context, log),
                        ),
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
      appBar:
          appBar ??
          AppBar(
            title: const SizedBox.shrink(),
            actions: [
              _NotificationBell(
                onActivitySelected: (log) =>
                    _openActivityLocation(context, log),
              ),
              _SettingsMenu(),
              const SizedBox(width: 8),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(46),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _HeaderSearchField(width: _searchWidth(context)),
                ),
              ),
            ),
          ),
      drawer: AppDrawer(
        selectedIndex: selectedIndex,
        onItemTap: onItemTap,
        items: items,
        darkSidebar: darkSidebar,
      ),
      body: body,
    );
  }

  double _searchWidth(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth >= 900) return 300;
    return (screenWidth - 32).clamp(120.0, 600.0).toDouble();
  }

  void _openActivityLocation(BuildContext context, AuditLog log) {
    final role = context.read<AuthProvider>().user?.role;
    switch (log.eventType) {
      case 'sale_recorded':
      case 'sale_approved':
        onItemTap(4, childIndex: 0);
        break;
      case 'expense_recorded':
        onItemTap(4, childIndex: 1);
        break;
      case 'credit_paid':
        onItemTap(4, childIndex: 2);
        break;
      case 'purchase_recorded':
      case 'purchase_edited':
      case 'purchase_approved':
      case 'stock_merged':
        onItemTap(4, childIndex: 3);
        break;
      case 'damage_recorded':
        onItemTap(4, childIndex: 4);
        break;
      case 'product_created':
      case 'product_updated':
      case 'product_deleted':
      case 'low_stock_alert':
        onItemTap(2);
        break;
      case 'category_created':
      case 'category_updated':
      case 'category_deleted':
        onItemTap(3, childIndex: log.details?['type'] == 'expense' ? 1 : 0);
        break;
      case 'supplier_created':
      case 'supplier_updated':
      case 'supplier_deleted':
        onItemTap(1, childIndex: 0);
        break;
      case 'employee_created_primary':
      case 'employee_created_backup':
      case 'employee_deleted':
      case 'employee_permissions_updated':
      case 'employee_suspended':
      case 'employee_reactivated':
        if (role == 'admin') onItemTap(1, childIndex: 1);
        break;
    }
  }
}

class _HeaderSearchField extends StatefulWidget {
  final double width;

  const _HeaderSearchField({required this.width});

  @override
  State<_HeaderSearchField> createState() => _HeaderSearchFieldState();
}

class _HeaderSearchFieldState extends State<_HeaderSearchField> {
  final TextEditingController _controller = TextEditingController();
  Timer? _searchTimer;

  @override
  void dispose() {
    _searchTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _emitSearch() {
    AppEvents.instance.emit(
      '${AppEvents.globalSearchPrefix}${_controller.text.trim()}',
    );
  }

  void _submit() {
    _searchTimer?.cancel();
    _emitSearch();
    setState(() {});
  }

  void _clear() {
    _searchTimer?.cancel();
    _controller.clear();
    _emitSearch();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: 38,
      child: TextField(
        controller: _controller,
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => _submit(),
        onChanged: (_) {
          setState(() {});
          _searchTimer?.cancel();
          _searchTimer = Timer(const Duration(milliseconds: 300), _emitSearch);
        },
        style: TextStyle(fontSize: 12, color: AppTheme.textColor(context)),
        decoration: InputDecoration(
          hintText: 'Search stock, sales, suppliers...',
          hintStyle: TextStyle(
            fontSize: 12,
            color: AppTheme.secondaryText(context),
          ),
          prefixIcon: Icon(
            Icons.search,
            size: 18,
            color: AppTheme.secondaryText(context),
          ),
          suffixIcon: IconButton(
            onPressed: _controller.text.isEmpty ? _submit : _clear,
            tooltip: _controller.text.isEmpty ? 'Search' : 'Clear search',
            icon: Icon(
              _controller.text.isEmpty ? Icons.search : Icons.close,
              size: 17,
              color: AppTheme.secondaryText(context),
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          isDense: true,
          filled: true,
          fillColor: AppTheme.panelColor(context),
          contentPadding: const EdgeInsets.symmetric(vertical: 9),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: AppTheme.borderColor(context)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: AppTheme.borderColor(context)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
          ),
        ),
      ),
    );
  }
}

class _NotificationBell extends StatefulWidget {
  final ValueChanged<AuditLog> onActivitySelected;

  const _NotificationBell({required this.onActivitySelected});

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
    if ([
      'sales',
      'purchases',
      'damages',
      'products',
      'categories',
    ].contains(event)) {
      _fetchUnread();
    }
  }

  Future<void> _fetchUnread() async {
    try {
      final res = await ApiService.getActivity(limit: 1);
      if (mounted) setState(() => _unread = (res['unreadCount'] ?? 0) as int);
    } catch (_) {}
  }

  Future<void> _open() async {
    final log = await Navigator.push<AuditLog>(
      context,
      MaterialPageRoute(builder: (_) => const ActivityNotificationsScreen()),
    );
    if (!mounted) return;
    if (log != null) widget.onActivitySelected(log);
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
          icon: Icon(
            Icons.notifications_outlined,
            color: AppTheme.mutedIcon(context),
          ),
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
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
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

    return PopupMenuButton<String>(
      offset: const Offset(0, 36),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      icon: Icon(
        Icons.settings_outlined,
        color: AppTheme.mutedIcon(context),
        size: 22,
      ),
      onSelected: (value) {
        if (value == 'profile') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ProfileScreen()),
          );
        } else if (value == 'logout') {
          auth.logout();
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem<String>(
          value: 'profile',
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.account_circle_outlined,
                size: 16,
                color: AppTheme.dashNavy,
              ),
              const SizedBox(width: 8),
              Text(
                'My Profile',
                style: TextStyle(
                  fontSize: AppTheme.fontSize(context, 13),
                  fontWeight: FontWeight.w600,
                ),
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
              Text(
                'Logout',
                style: TextStyle(
                  fontSize: AppTheme.fontSize(context, 13),
                  color: AppTheme.danger,
                ),
              ),
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

  /// Nested branches shown under this item in a tree (e.g. Transactions
  /// > History). When set, the row renders as an expandable parent.
  final List<DrawerChildItem>? children;

  /// Which child branch is currently selected (highlighted), if any.
  final int? activeChildIndex;

  /// Whether the branch starts expanded. Defaults to expanded when active.
  final bool? initiallyExpanded;

  const DrawerItem({
    required this.icon,
    required this.label,
    required this.builder,
    this.children,
    this.activeChildIndex,
    this.initiallyExpanded,
  });

  bool get hasChildren => children != null && children!.isNotEmpty;
}
