import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'features/home/home_screen.dart';

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
    return MaterialApp(
      title: 'SanBidet Cebu',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF1A6B3C),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}