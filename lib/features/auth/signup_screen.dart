import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../../services/auth_service.dart';
import '../map/map_screen.dart';

/// shadcn "signup-01" block, adapted to Flutter via shadcn_ui.
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _auth = AuthService();

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  int _passwordStrength(String password) {
    if (password.isEmpty) return 0;
    int score = 0;
    if (password.length >= 8) score++;
    if (RegExp(r'[a-z]').hasMatch(password)) score++;
    if (RegExp(r'[A-Z]').hasMatch(password)) score++;
    if (RegExp(r'[0-9]').hasMatch(password)) score++;
    if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) score++;
    return score;
  }

  Future<void> _signup() async {
    final username = _usernameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    if (username.isEmpty) {
      setState(() => _error = 'Please enter a username.');
      return;
    }
    if (password.length < 8) {
      setState(() => _error = 'Password must be at least 8 characters.');
      return;
    }
    if (password != confirm) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _auth.signUp(email, password, username: username);
      if (!mounted) return;
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const MapScreen()));
    } catch (e) {
      setState(() {
        _error = 'Could not create account. Try again.';
        _loading = false;
      });
    }
  }

  void _googleStub() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Google sign-up isn't set up yet.")),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final password = _passwordController.text;
    final strength = _passwordStrength(password);

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
                title: const Text('Create an account'),
                description: const Text(
                  'Enter your details below to create your account',
                ),
                child: Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ShadInputFormField(
                        controller: _usernameController,
                        label: const Text('Username'),
                        placeholder: const Text('bidet_hunter'),
                      ),
                      const SizedBox(height: 16),
                      ShadInputFormField(
                        controller: _emailController,
                        label: const Text('Email'),
                        placeholder: const Text('m@example.com'),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 16),
                      ShadInputFormField(
                        controller: _passwordController,
                        label: const Text('Password'),
                        placeholder: const Text('At least 8 characters'),
                        obscureText: true,
                        onChanged: (_) => setState(() {}),
                      ),
                      if (password.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _StrengthBar(strength: strength),
                      ],
                      const SizedBox(height: 16),
                      ShadInputFormField(
                        controller: _confirmController,
                        label: const Text('Confirm password'),
                        placeholder: const Text('Re-enter your password'),
                        obscureText: true,
                        onSubmitted: (_) => _loading ? null : _signup(),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 14),
                        _ErrorBox(_error!),
                      ],
                      const SizedBox(height: 22),
                      ShadButton(
                        width: double.infinity,
                        onPressed: _loading ? null : _signup,
                        child: _loading
                            ? const _Spinner()
                            : const Text('Create account'),
                      ),
                      const SizedBox(height: 10),
                      ShadButton.outline(
                        width: double.infinity,
                        onPressed: _googleStub,
                        child: const Text('Sign up with Google'),
                      ),
                      const SizedBox(height: 18),
                      Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Already have an account? ',
                              style: theme.textTheme.muted,
                            ),
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: Text(
                                'Login',
                                style: theme.textTheme.small.copyWith(
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
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

class _StrengthBar extends StatelessWidget {
  final int strength;
  const _StrengthBar({required this.strength});

  @override
  Widget build(BuildContext context) {
    const labels = ['', 'Very weak', 'Weak', 'Fair', 'Strong', 'Very strong'];
    final colors = [
      Colors.transparent,
      Colors.red,
      Colors.orange,
      Colors.yellow.shade700,
      Colors.lightGreen,
      const Color(0xFF16A34A),
    ];
    final clamped = strength.clamp(0, 5);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(5, (i) {
            return Expanded(
              child: Container(
                height: 4,
                margin: EdgeInsets.only(right: i < 4 ? 4 : 0),
                decoration: BoxDecoration(
                  color: i < strength ? colors[clamped] : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 4),
        Text(
          clamped > 0 ? labels[clamped] : '',
          style: TextStyle(
            fontSize: 11,
            color: colors[clamped],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
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
