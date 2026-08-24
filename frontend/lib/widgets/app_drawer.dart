import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_provider.dart';
import '../services/theme_provider.dart';
import '../utils/theme.dart';

/// Breakpoint width: screens wider than this show the permanent sidebar.
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

/// Permanent sidebar for wide screens (laptops, desktops).
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

/// Shared drawer/sidebar content.
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
          // Branding header
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
                      'http://10.0.2.2:5000${branding!.businessLogo!}',
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: AppTheme.fontSize(context, isSmall ? 15 : 17),
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          // Nav items
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

/// Responsive wrapper: shows permanent sidebar on wide screens,
/// and a drawer (hamburger menu) on narrow screens.
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
      // Wide screen: permanent sidebar + body
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
                    IconButton(
                      icon: Icon(Icons.notifications_outlined, color: AppTheme.mutedIcon(context)),
                      onPressed: () {},
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

    // Narrow screen: drawer (hamburger)
    return Scaffold(
      appBar: appBar ?? AppBar(title: Text(title ?? '')),
      drawer: AppDrawer(
        selectedIndex: selectedIndex,
        onItemTap: onItemTap,
        items: items,
      ),
      body: body,
    );
  }
}

/// Settings menu shown as a popup from the AppBar settings icon.
class _SettingsMenu extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final themeProvider = context.watch<ThemeProvider>();

    return PopupMenuButton<String>(
      offset: const Offset(0, 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      icon: Icon(Icons.settings_outlined, color: AppTheme.mutedIcon(context)),
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
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                themeProvider.isDark ? Icons.light_mode : Icons.dark_mode,
                size: 20,
                color: themeProvider.isDark ? Colors.amber : Colors.grey.shade600,
              ),
              const SizedBox(width: 12),
              Text(
                themeProvider.isDark ? 'Light Mode' : 'Dark Mode',
                style: TextStyle(fontSize: AppTheme.fontSize(context, 14)),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 40,
                child: Switch(
                  value: themeProvider.isDark,
                  onChanged: (_) => themeProvider.toggle(),
                  activeColor: AppTheme.primary,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'logout',
          child: Row(
            children: [
              const Icon(Icons.logout, size: 20, color: AppTheme.danger),
              const SizedBox(width: 12),
              Text('Logout',
                style: TextStyle(
                  fontSize: AppTheme.fontSize(context, 14),
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
