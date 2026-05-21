import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'welcome_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://ebwubdwcksqihxiycdna.supabase.co',
    anonKey: 'sb_publishable_0SXIMX7YlPmkey6HoQ_KYg_L76gdA_X',
  );
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
      theme: ThemeData(
        fontFamily: 'Poppins',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2979FF),
        ),
      ),
      home: const WelcomePage(),
    );
  }
}
