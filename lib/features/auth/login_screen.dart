import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../../services/auth_service.dart';
import '../dashboard/dashboard_screen.dart';
import '../map/map_screen.dart';
import '../admin/admin_screen.dart';
import 'signup_screen.dart';

/// shadcn "login-01" block, adapted to Flutter via shadcn_ui.
class LoginScreen extends StatefulWidget {
  final bool isAdmin;
  const LoginScreen({super.key, this.isAdmin = false});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _auth = AuthService();
  bool _loading = false;
  String? _error;
  bool _navigated = false;
  StreamSubscription<dynamic>? _authSub;

  @override
  void initState() {
    super.initState();
    // Route to the map when a session appears — this covers returning from the
    // Google OAuth redirect (web reloads the page) and an existing session.
    _authSub = _auth.authStateChanges.listen((_) => _maybeRouteToMap());
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeRouteToMap());
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Admin login uses its own routing; everyone else lands on the dashboard.
  void _maybeRouteToMap() {
    if (_navigated || widget.isAdmin || !mounted) return;
    if (_auth.currentUser == null) return;
    _navigated = true;
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => const DashboardScreen()));
  }

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _auth.signIn(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      if (!mounted) return;

      if (widget.isAdmin) {
        final admin = await _auth.isAdmin();
        if (!mounted) return;
        if (!admin) {
          await _auth.signOut();
          setState(() {
            _error = 'This account does not have admin access.';
            _loading = false;
          });
          return;
        }
        _navigated = true;
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => const AdminScreen()));
      } else {
        _maybeRouteToMap();
      }
    } catch (e) {
      setState(() {
        _error = 'Invalid email or password.';
        _loading = false;
      });
    }
  }

  Future<void> _googleSignIn() async {
    try {
      await _auth.signInWithGoogle();
      // Web: the page redirects away now. Mobile: returns via the auth
      // listener. Nothing else to do here.
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not start Google sign-in.')),
      );
    }
  }

  void _forgotStub() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Password reset isn\'t set up yet.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.muted,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: ShadCard(
                width: double.infinity,
                title: Text(
                  widget.isAdmin ? 'Admin login' : 'Login to your account',
                ),
                description: Text(
                  widget.isAdmin
                      ? 'Enter your admin credentials below to continue'
                      : 'Enter your email below to login to your account',
                ),
                child: Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ShadInputFormField(
                        controller: _emailController,
                        label: const Text('Email'),
                        placeholder: const Text('m@example.com'),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 16),
                      ShadInputFormField(
                        controller: _passwordController,
                        obscureText: true,
                        label: Row(
                          children: [
                            const Text('Password'),
                            const Spacer(),
                            ShadButton.link(
                              padding: EdgeInsets.zero,
                              onPressed: _forgotStub,
                              child: const Text('Forgot your password?'),
                            ),
                          ],
                        ),
                        onSubmitted: (_) => _loading ? null : _login(),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 14),
                        _ErrorBox(_error!),
                      ],
                      const SizedBox(height: 22),
                      ShadButton(
                        width: double.infinity,
                        onPressed: _loading ? null : _login,
                        child: _loading
                            ? const _Spinner()
                            : const Text('Login'),
                      ),
                      const SizedBox(height: 10),
                      ShadButton.outline(
                        width: double.infinity,
                        onPressed: _googleSignIn,
                        child: const Text('Login with Google'),
                      ),
                      if (!widget.isAdmin) ...[
                        const SizedBox(height: 18),
                        Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                "Don't have an account? ",
                                style: theme.textTheme.muted,
                              ),
                              GestureDetector(
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const SignupScreen()),
                                ),
                                child: Text(
                                  'Sign up',
                                  style: theme.textTheme.small.copyWith(
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Center(
                          child: ShadButton.link(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const MapScreen()),
                            ),
                            child: const Text('Browse as guest'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String message;
  const _ErrorBox(this.message);

  @override
  Widget build(BuildContext context) {
    final cs = ShadTheme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.destructive.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        message,
        style: TextStyle(color: cs.destructive, fontSize: 13),
      ),
    );
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 16,
      width: 16,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: ShadTheme.of(context).colorScheme.primaryForeground,
      ),
    );
  }
}
