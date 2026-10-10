import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'services/auth_provider.dart';
import 'services/notification_sound_service.dart';
import 'services/theme_provider.dart';
import 'utils/theme.dart';
import 'screens/auth/login_screen.dart';
import 'screens/developer/developer_home.dart';
import 'screens/admin/admin_home.dart';
import 'screens/employee/employee_home.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: ".env");
  } catch (_) {}

  NotificationSoundService.instance.preload(); 
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
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()..init()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) => MaterialApp(
          title: 'Store House',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.theme.copyWith(
            colorScheme: AppTheme.theme.colorScheme.copyWith(
              primary: themeProvider.accentColor,
            ),
            primaryColor: themeProvider.accentColor,
          ),
          darkTheme: AppTheme.darkTheme.copyWith(
            colorScheme: AppTheme.darkTheme.colorScheme.copyWith(
              primary: themeProvider.accentColor,
            ),
            primaryColor: themeProvider.accentColor,
          ),
          themeMode: themeProvider.themeMode,
          themeAnimationDuration: Duration.zero, 
          home: const AuthGate(),

        builder: (context, child) {
          final mediaQuery = MediaQuery.of(context);
          final currentScale = mediaQuery.textScaler.scale(14) / 14; 
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
      ),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<AuthProvider>().refreshBranding();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        if (auth.loading) {
          if (AppTheme.isPhoneScreen(context)) {
            return const Scaffold(body: StoreHouseSplash());
          }
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (!auth.isAuthenticated) {
          return const LoginScreen();
        }

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