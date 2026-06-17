import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'welcome_page.dart';
import 'splash_page.dart';
import 'home_page.dart';
import 'inventory_page.dart';
import 'pos_page.dart';
import 'sales_checkout_page.dart';
import 'profile_page.dart';
import 'login_page.dart';
import 'forgot_password_page.dart';
import 'change_password_page.dart';
import 'notification_service.dart';
import 'inventory_realtime_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://ebwubdwcksqihxiycdna.supabase.co',
    anonKey: 'sb_publishable_0SXIMX7YlPmkey6HoQ_KYg_L76gdA_X',
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.implicit,
    ),
  );
  // Initialize OS notifications
  await NotificationService().init();
  await NotificationService().requestPermission();
  runApp(const MyApp());
}

/// Global accessor for the Supabase client — use throughout the app.
final supabase = Supabase.instance.client;

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  bool _isRecoveringPassword = false;

  @override
  void initState() {
    super.initState();
    _setupAuthListener();
    InventoryRealtimeService().start();
  }

  void _setupAuthListener() {
    supabase.auth.onAuthStateChange.listen((data) async {
      final AuthChangeEvent event = data.event;

      debugPrint('Supabase Auth Event: $event');

      if (event == AuthChangeEvent.passwordRecovery) {
        _isRecoveringPassword = true;
        // Recovery harus instan, tanpa nunggu splash
        while (_navigatorKey.currentState == null) {
          await Future.delayed(const Duration(milliseconds: 50));
        }
        _navigatorKey.currentState?.pushNamedAndRemoveUntil('/change-password', (route) => false);
        return;
      }

      // Password berhasil diubah — reset flag supaya login normal berikutnya tidak terblokir.
      if (event == AuthChangeEvent.userUpdated) {
        _isRecoveringPassword = false;
        return;
      }

      if (event == AuthChangeEvent.initialSession) {
        // Abaikan initialSession di sini.
        // Navigasi awal akan ditangani langsung oleh SplashPage setelah animasi selesai.
      } else if (event == AuthChangeEvent.signedIn) {
        InventoryRealtimeService().start();
        _navigatorKey.currentState?.pushNamedAndRemoveUntil('/home', (route) => false);
      } else if (event == AuthChangeEvent.signedOut) {
        InventoryRealtimeService().stop();
        _navigatorKey.currentState?.pushNamedAndRemoveUntil('/welcome', (route) => false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SiKulak',
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      scrollBehavior: MyCustomScrollBehavior(),
      theme: ThemeData(
        fontFamily: 'Poppins',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2979FF),
        ),
      ),
      home: const SplashPage(),
      routes: {
        '/home': (context) => const HomePage(),
        '/login': (context) => const LoginPage(),
        '/welcome': (context) => const WelcomePage(),
        '/inventory': (context) => const InventoryPage(),
        '/pos': (context) => const PosPage(),
        '/checkout': (context) => const SalesCheckoutPage(),
        '/profile': (context) => const ProfilePage(),
        '/forgot-password': (context) => const ForgotPasswordPage(),
        '/change-password': (context) => const ChangePasswordPage(),
      },
    );
  }
}

class MyCustomScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
      };
}
