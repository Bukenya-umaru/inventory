import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_provider.dart';
import '../utils/theme.dart';

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
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final branding = auth.branding;
    final size = MediaQuery.of(context).size;
    final isSmall = size.height < 600 || size.width < 400;

    return Drawer(
      width: size.width < 400 ? size.width * 0.82 : 260,
      child: SafeArea(
        child: Column(
          children: [
            // Branding header
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(isSmall ? 14 : 20),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.05),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (branding?.businessLogo != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        'http://10.0.2.2:5000${branding!.businessLogo!}',
                        height: isSmall ? 32 : 40,
                        errorBuilder: (_, __, ___) => Icon(Icons.business, size: isSmall ? 32 : 40),
                      ),
                    )
                  else
                    Icon(Icons.business, size: isSmall ? 32 : 40, color: AppTheme.primary),
                  SizedBox(height: isSmall ? 6 : 8),
                  Text(
                    branding?.businessName ?? 'Inventory System',
                    style: TextStyle(fontSize: isSmall ? 14 : 16, fontWeight: FontWeight.bold),
                  ),
                  if (branding?.phoneNumber != null)
                    Text(
                      branding!.phoneNumber!,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                ],
              ),
            ),
            // User info
            Container(
              padding: EdgeInsets.symmetric(horizontal: isSmall ? 14 : 20, vertical: isSmall ? 8 : 12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: isSmall ? 16 : 18,
                    backgroundColor: _roleColor(user?.role).withValues(alpha: 0.1),
                    child: Text(
                      (user?.name ?? '?')[0].toUpperCase(),
                      style: TextStyle(
                        color: _roleColor(user?.role),
                        fontWeight: FontWeight.bold,
                        fontSize: isSmall ? 13 : 14,
                      ),
                    ),
                  ),
                  SizedBox(width: isSmall ? 8 : 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.name ?? '',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: isSmall ? 13 : 14,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _roleColor(user?.role).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            (user?.role ?? '').toUpperCase(),
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: _roleColor(user?.role),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Nav items
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 6),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  final isActive = selectedIndex == index;
                  return ListTile(
                    dense: isSmall,
                    visualDensity: VisualDensity.compact,
                    leading: Icon(
                      item.icon,
                      color: isActive ? AppTheme.primary : Colors.grey.shade600,
                      size: isSmall ? 20 : 22,
                    ),
                    title: Text(
                      item.label,
                      style: TextStyle(
                        fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                        color: isActive ? AppTheme.primary : Colors.grey.shade800,
                        fontSize: isSmall ? 13 : 14,
                      ),
                    ),
                    selected: isActive,
                    selectedTileColor: AppTheme.primary.withValues(alpha: 0.08),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: EdgeInsets.symmetric(horizontal: isSmall ? 12 : 16),
                    onTap: () {
                      onItemTap(index);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
            const Divider(height: 1),
            // Logout
            ListTile(
              dense: isSmall,
              visualDensity: VisualDensity.compact,
              leading: const Icon(Icons.logout, color: AppTheme.danger, size: 20),
              title: const Text(
                'Logout',
                style: TextStyle(color: AppTheme.danger, fontWeight: FontWeight.w500, fontSize: 14),
              ),
              onTap: () => auth.logout(),
            ),
          ],
        ),
      ),
    );
  }

  Color _roleColor(String? role) {
    switch (role) {
      case 'developer':
        return const Color(0xFF7C3AED);
      case 'admin':
        return AppTheme.primary;
      default:
        return AppTheme.success;
    }
  }
}

class DrawerItem {
  final IconData icon;
  final String label;
  final Widget Function() builder;

  const DrawerItem({required this.icon, required this.label, required this.builder});
}
