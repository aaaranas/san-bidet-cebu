import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'features/auth/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://xwpmgvrvxqrvlmnxdvyp.supabase.co',
    anonKey: 'sb_publishable_Hf0du3Xu6HrtpBwkUhdXqQ_xxVNKXlJ',
  );

  runApp(const SanBidetApp());
}

class SanBidetApp extends StatelessWidget {
  const SanBidetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ShadApp(
      title: 'SanBidet Cebu',
      debugShowCheckedModeBanner: false,
      theme: ShadThemeData(
        brightness: Brightness.light,
        colorScheme: const ShadSlateColorScheme.light(),
      ),
      // Slate palette for the Material screens too (M3 default).
      materialThemeBuilder: (context, theme) => theme.copyWith(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0F172A)),
      ),
      home: const LoginScreen(),
    );
  }
}