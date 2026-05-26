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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://ebwubdwcksqihxiycdna.supabase.co',
    anonKey: 'sb_publishable_0SXIMX7YlPmkey6HoQ_KYg_L76gdA_X',
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

  @override
  void initState() {
    super.initState();
    _setupAuthListener();
  }

  void _setupAuthListener() {
    bool initialNavDone = false;

    supabase.auth.onAuthStateChange.listen((data) async {
      final AuthChangeEvent event = data.event;
      final Session? session = data.session;

      if (event == AuthChangeEvent.passwordRecovery) {
        initialNavDone = true;
        _navigatorKey.currentState?.pushNamedAndRemoveUntil('/change-password', (route) => false);
        return;
      }

      // Allow splash screen to show for a bit for normal app launches
      if (!initialNavDone) {
        await Future.delayed(const Duration(milliseconds: 2000));
        initialNavDone = true;
      }

      if (event == AuthChangeEvent.signedIn) {
        // Double check we're not in password recovery state to be safe
        _navigatorKey.currentState?.pushNamedAndRemoveUntil('/home', (route) => false);
      } else if (event == AuthChangeEvent.signedOut || (event == AuthChangeEvent.initialSession && session == null)) {
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
