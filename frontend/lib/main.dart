import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'services/auth_provider.dart';
import 'utils/theme.dart';
import 'screens/auth/login_screen.dart';
import 'screens/developer/developer_home.dart';
import 'screens/admin/admin_home.dart';
import 'screens/employee/employee_home.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const InventoryApp());
}

class InventoryApp extends StatelessWidget {
  const InventoryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthProvider()..init(),
      child: MaterialApp(
        title: 'Inventory Management',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.theme,
        home: const AuthGate(),
        // Allow system font scaling (accessibility) but cap at 1.5x
        builder: (context, child) {
          final mediaQuery = MediaQuery.of(context);
          final currentScale = mediaQuery.textScaler.scale(14) / 14; // derive factor
          final clampedScaler = TextScaler.linear(
            currentScale.clamp(0.8, 1.5),
          );
          return MediaQuery(
            data: mediaQuery.copyWith(
              textScaler: clampedScaler,
            ),
            child: child!,
          );
        },
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (auth.loading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (!auth.isAuthenticated) {
          return const LoginScreen();
        }
        // Route based on role — same login, different dashboards
        switch (auth.user!.role) {
          case 'developer':
            return const DeveloperHome();
          case 'admin':
            return const AdminHome();
          case 'employee':
          default:
            return const EmployeeHome();
        }
      },
    );
  }
}
