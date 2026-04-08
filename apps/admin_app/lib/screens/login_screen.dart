import 'package:coach_flow_core/coach_flow_core.dart';
import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.authRepository,
    required this.onAuthenticated,
  });

  final AuthRepository authRepository;
  final ValueChanged<AuthSession> onAuthenticated;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController(
    text: 'superadmin@platform.app',
  );
  final _passwordController = TextEditingController(text: 'superadmin12345');
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final session = await widget.authRepository.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (session.role != 'admin' && session.role != 'super_admin') {
        await widget.authRepository.logout();
        throw const ApiException('This account does not have admin access.');
      }
      widget.onAuthenticated(session);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Platform Console',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Sign in as super admin to create gym-owner accounts, or sign in as a gym owner to manage members, programs, invoices, and communication.',
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _emailController,
                      decoration: const InputDecoration(labelText: 'Email'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: 'Password'),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _submitting ? null : _submit,
                        child: Text(_submitting ? 'Signing in...' : 'Sign in'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Super admin: superadmin@platform.app / superadmin12345',
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Gym owner demo: admin@abhaymethod.app / admin12345',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
