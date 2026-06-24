import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final _supabase = Supabase.instance.client;

  // Deep-link scheme used on Android/iOS to return from the Google sign-in
  // browser. Must match the redirect registered in the Supabase dashboard and
  // the platform deep-link config. On web, the OAuth flow returns to the site
  // URL configured in Supabase, so no redirect is passed.
  static const _mobileRedirect = 'io.supabase.sanbidetcebu://login-callback/';

  /// Starts the Google OAuth flow. On web this redirects the page to Google
  /// and back; on mobile it opens an external browser and returns via the
  /// deep link. The resulting session arrives through [authStateChanges].
  Future<void> signInWithGoogle() async {
    await _supabase.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: kIsWeb ? null : _mobileRedirect,
    );
  }

  User? get currentUser => _supabase.auth.currentUser;

  Stream<AuthState> get authStateChanges =>
      _supabase.auth.onAuthStateChange;

  String? get currentUsername =>
      currentUser?.userMetadata?['username'] as String?;

  Future<void> signUp(String email, String password,
      {String? username}) async {
    await _supabase.auth.signUp(
      email: email,
      password: password,
      data: username != null ? {'username': username} : null,
    );
  }

  Future<void> signIn(String email, String password) async {
    await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  Future<String> getRole() async {
    final user = currentUser;
    if (user == null) return 'user';
    final data = await _supabase
        .from('profiles')
        .select('role')
        .eq('id', user.id)
        .single();
    return data['role'] ?? 'user';
  }

  Future<bool> isAdmin() async => (await getRole()) == 'admin';
}
