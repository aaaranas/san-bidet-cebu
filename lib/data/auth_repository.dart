import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Domain-level view of the signed-in user, so screens never import Supabase
/// types directly.
class AppUser {
  final String id;
  final String? email;
  final String? username;
  final bool isAdmin;

  const AppUser({
    required this.id,
    this.email,
    this.username,
    this.isAdmin = false,
  });

  String get displayName => username ?? email?.split('@').first ?? 'there';
}

/// Raised for sign-in/sign-up problems that the UI should show verbatim,
/// so a network failure is no longer reported as "invalid password".
class AuthFailure implements Exception {
  final String message;
  const AuthFailure(this.message);

  @override
  String toString() => message;
}

abstract interface class AuthRepository {
  AppUser? get currentUser;

  /// Emits on sign-in, sign-out and token refresh.
  Stream<AppUser?> watchUser();

  Future<AppUser> signIn(String email, String password);

  Future<AppUser> signUp(String email, String password, {required String username});

  /// Starts the Google OAuth flow. Returns before sign-in completes: on web the
  /// page redirects to Google and back, on mobile an external browser opens and
  /// returns via deep link. The resulting session arrives through [watchUser].
  Future<void> signInWithGoogle();

  Future<void> signOut();

  /// Re-reads the profile row (role may have changed server-side).
  Future<AppUser?> refresh();
}

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final SupabaseClient _client;

  /// Cached role, refreshed whenever the auth state changes.
  bool _isAdmin = false;

  @override
  AppUser? get currentUser => _toAppUser(_client.auth.currentUser);

  AppUser? _toAppUser(User? user) {
    if (user == null) return null;
    return AppUser(
      id: user.id,
      email: user.email,
      username: user.userMetadata?['username'] as String?,
      isAdmin: _isAdmin,
    );
  }

  @override
  Stream<AppUser?> watchUser() async* {
    // Emit the restored session immediately so a web refresh does not bounce
    // a signed-in user back to the landing page.
    _isAdmin = await _fetchIsAdmin(_client.auth.currentUser?.id);
    yield _toAppUser(_client.auth.currentUser);

    await for (final state in _client.auth.onAuthStateChange) {
      final user = state.session?.user;
      _isAdmin = await _fetchIsAdmin(user?.id);
      yield _toAppUser(user);
    }
  }

  /// Reads the role from `profiles`.
  ///
  /// Uses maybeSingle(): the previous single() threw when a user had no
  /// profile row, and that throw surfaced in the login screen as
  /// "Invalid email or password" — an error the user could never fix.
  Future<bool> _fetchIsAdmin(String? userId) async {
    if (userId == null) return false;
    try {
      final row = await _client
          .from('profiles')
          .select('role')
          .eq('id', userId)
          .maybeSingle();
      return (row?['role'] as String?) == 'admin';
    } catch (_) {
      // A missing profile row or a transient failure means "not an admin",
      // never "bad credentials".
      return false;
    }
  }

  @override
  Future<AppUser> signIn(String email, String password) async {
    try {
      final res = await _client.auth
          .signInWithPassword(email: email, password: password);
      final user = res.user;
      if (user == null) {
        throw const AuthFailure('Could not sign in. Please try again.');
      }
      _isAdmin = await _fetchIsAdmin(user.id);
      return _toAppUser(user)!;
    } on AuthApiException catch (e) {
      throw AuthFailure(_friendly(e));
    } on AuthException catch (e) {
      throw AuthFailure(e.message);
    }
  }

  @override
  Future<AppUser> signUp(
    String email,
    String password, {
    required String username,
  }) async {
    try {
      final res = await _client.auth.signUp(
        email: email,
        password: password,
        data: {'username': username},
      );
      final user = res.user;
      if (user == null) {
        throw const AuthFailure(
          'Check your inbox to confirm your address before signing in.',
        );
      }
      _isAdmin = await _fetchIsAdmin(user.id);
      return _toAppUser(user)!;
    } on AuthApiException catch (e) {
      throw AuthFailure(_friendly(e));
    } on AuthException catch (e) {
      throw AuthFailure(e.message);
    }
  }

  /// Maps Supabase codes to copy a user can act on. Anything unrecognised
  /// keeps the server's own message rather than being flattened.
  String _friendly(AuthApiException e) {
    final msg = e.message.toLowerCase();
    if (msg.contains('invalid login credentials')) {
      return 'That email and password do not match an account.';
    }
    if (msg.contains('email not confirmed')) {
      return 'Please confirm your email address first — check your inbox.';
    }
    if (msg.contains('already registered') ||
        msg.contains('already been registered')) {
      return 'An account with that email already exists. Try signing in.';
    }
    if (msg.contains('rate limit') || msg.contains('too many')) {
      return 'Too many attempts. Please wait a minute and try again.';
    }
    return e.message;
  }

  /// Deep-link scheme used on Android/iOS to return from the Google sign-in
  /// browser. Must match the redirect registered in the Supabase dashboard and
  /// the platform deep-link config. On web the flow returns to the site URL
  /// configured in Supabase, so no redirect is passed.
  static const _mobileRedirect = 'io.supabase.sanbidetcebu://login-callback/';

  @override
  Future<void> signInWithGoogle() async {
    try {
      await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb ? null : _mobileRedirect,
      );
    } on AuthApiException catch (e) {
      throw AuthFailure(_friendly(e));
    } on AuthException catch (e) {
      throw AuthFailure(e.message);
    }
  }

  @override
  Future<void> signOut() async {
    await _client.auth.signOut();
    _isAdmin = false;
  }

  @override
  Future<AppUser?> refresh() async {
    final user = _client.auth.currentUser;
    _isAdmin = await _fetchIsAdmin(user?.id);
    return _toAppUser(user);
  }
}
