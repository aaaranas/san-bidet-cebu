/// Build-time configuration.
///
/// Values come from `--dart-define` so the same source tree can target a
/// staging and a production Supabase project without edits:
///
///   flutter build web --release \
///     --dart-define=SUPABASE_URL=https://xxx.supabase.co \
///     --dart-define=SUPABASE_ANON_KEY=sb_publishable_xxx
///
/// The defaults below point at the current project so existing workflows keep
/// working. The anon/publishable key is safe to ship in a client — it only
/// grants what your RLS policies allow — but the URL/key pair still belongs in
/// configuration rather than source.
class AppConfig {
  const AppConfig._();

  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://xwpmgvrvxqrvlmnxdvyp.supabase.co',
  );

  static const supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_Hf0du3Xu6HrtpBwkUhdXqQ_xxVNKXlJ',
  );

  /// Sent to the OSM/Esri tile servers. Must match the real application id —
  /// tile providers rate-limit by user agent.
  static const tileUserAgent = 'ph.sanbidet.cebu';

  /// Public origin of the deployed web app, used to build shareable links.
  static const webOrigin = String.fromEnvironment(
    'WEB_ORIGIN',
    defaultValue: 'https://sanbidet-cebu.vercel.app',
  );

  static const storageBucket = 'bidet-images';

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
