import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final _supabase = Supabase.instance.client;

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
