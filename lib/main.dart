import 'package:flutter/material.dart';
import 'features/map/map_screen.dart';

void main() {
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
      home: const MapScreen(),
    );
  }
}