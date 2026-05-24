import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'welcome_page.dart';
import 'splash_page.dart';
import 'inventory_page.dart';
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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SiKulak',
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
        '/welcome': (context) => const WelcomePage(),
        '/inventory': (context) => const InventoryPage(),
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
