import 'package:flutter/material.dart';

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
      home: const PlaceholderHome(),
    );
  }
}

class PlaceholderHome extends StatelessWidget {
  const PlaceholderHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SanBidet Cebu'),
        backgroundColor: const Color(0xFF1A6B3C),
        foregroundColor: Colors.white,
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.water_drop_outlined,
              size: 72,
              color: Color(0xFF1A6B3C),
            ),
            SizedBox(height: 16),
            Text(
              'SanBidet Cebu',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A6B3C),
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Mapping bidets across Cebu',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: const Color(0xFF1A6B3C),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }
}