import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/app_config.dart';
import 'data/auth_repository.dart';
import 'data/bidet_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
  );

  final client = Supabase.instance.client;

  runApp(
    SanBidetApp(
      bidets: SupabaseBidetRepository(client),
      auth: SupabaseAuthRepository(client),
    ),
  );
}
