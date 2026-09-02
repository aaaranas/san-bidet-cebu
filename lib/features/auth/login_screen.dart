import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../../core/app_scope.dart';
import '../../core/router.dart';
import '../../data/auth_repository.dart';

/// shadcn "login-01" block, adapted to Flutter via shadcn_ui.
class LoginScreen extends StatefulWidget {
  /// Requires the account to hold the admin role.
  final bool adminMode;

  /// Where to land after signing in — set by the router when a guard bounced
  /// the user here, so they resume what they were doing.
  final String? redirectTo;

  const LoginScreen({super.key, this.adminMode = false, this.redirectTo});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Routing on a restored or new session is handled centrally by the router's
  // redirect, which listens to SessionController — so this screen no longer
  // keeps its own auth subscription or pushes replacements itself. That also
  // covers returning from the Google OAuth redirect.

  Future<void> _login() async {
    // Resolved before the first await so no BuildContext crosses an async gap.
    final auth = context.auth;
    final router = GoRouter.of(context);

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = await auth.signIn(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (widget.adminMode && !user.isAdmin) {
        await auth.signOut();
        if (!mounted) return;
        setState(() {
          _error = 'This account does not have admin access.';
          _loading = false;
        });
        return;
      }

      if (!mounted) return;
      router.go(widget.redirectTo ??
          (user.isAdmin && widget.adminMode ? Routes.admin : Routes.dashboard));
    } on AuthFailure catch (e) {
      // Surfaces the real reason. The previous blanket catch reported every
      // failure — network errors and a missing profile row included — as
      // "Invalid email or password."
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Something went wrong. Check your connection and try again.';
        _loading = false;
      });
    }
  }

  Future<void> _googleSignIn() async {
    final auth = context.auth;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await auth.signInWithGoogle();
      // Web: the page redirects away now. Mobile: the session arrives through
      // SessionController and the router redirect takes it from there.
    } on AuthFailure catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      messenger.showSnackBar(
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
                  widget.adminMode ? 'Moderator sign in' : 'Welcome back',
                ),
                description: Text(
                  widget.adminMode
                      ? 'Only moderator accounts can review submissions.'
                      : 'Sign in to add bidets and rate the ones you visit.',
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
                            : const Text('Sign in'),
                      ),
                      const SizedBox(height: 10),
                      ShadButton.outline(
                        width: double.infinity,
                        onPressed: _googleSignIn,
                        child: const Text('Continue with Google'),
                      ),
                      if (!widget.adminMode) ...[
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
                                onTap: () => context.push(Routes.signup),
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
                            onPressed: () => context.go(Routes.map),
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
