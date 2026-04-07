import 'package:coach_flow_core/coach_flow_core.dart';
import 'package:flutter/material.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    required this.authRepository,
    required this.onAuthenticated,
  });

  final AuthRepository authRepository;
  final ValueChanged<AuthSession> onAuthenticated;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _loginEmailController = TextEditingController(text: 'maya@example.com');
  final _loginPasswordController = TextEditingController(text: 'client12345');
  final _inviteCodeController = TextEditingController(text: 'ROHAN-START');
  final _activateEmailController = TextEditingController(text: 'rohan@example.com');
  final _activatePasswordController = TextEditingController(text: 'client12345');
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _inviteCodeController.dispose();
    _activateEmailController.dispose();
    _activatePasswordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    await _runAuthAction(() {
      return widget.authRepository.login(
        email: _loginEmailController.text.trim(),
        password: _loginPasswordController.text,
      );
    });
  }

  Future<void> _activate() async {
    await _runAuthAction(() {
      return widget.authRepository.activateClient(
        inviteCode: _inviteCodeController.text.trim(),
        email: _activateEmailController.text.trim(),
        password: _activatePasswordController.text,
      );
    });
  }

  Future<void> _runAuthAction(Future<AuthSession> Function() action) async {
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final session = await action();
      if (session.role != 'client') {
        await widget.authRepository.logout();
        throw const ApiException('This account is not a client account.');
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
                    Text('Client App', style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 12),
                    const Text('Log in with an existing account or activate your invite code.'),
                    const SizedBox(height: 20),
                    TabBar(
                      controller: _tabController,
                      tabs: const [
                        Tab(text: 'Login'),
                        Tab(text: 'Activate'),
                      ],
                    ),
                    SizedBox(
                      height: 280,
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          Column(
                            children: [
                              const SizedBox(height: 16),
                              TextField(
                                controller: _loginEmailController,
                                decoration: const InputDecoration(labelText: 'Email'),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _loginPasswordController,
                                obscureText: true,
                                decoration: const InputDecoration(labelText: 'Password'),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton(
                                  onPressed: _submitting ? null : _login,
                                  child: const Text('Log in'),
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text('Demo client: maya@example.com / client12345'),
                            ],
                          ),
                          Column(
                            children: [
                              const SizedBox(height: 16),
                              TextField(
                                controller: _inviteCodeController,
                                decoration: const InputDecoration(labelText: 'Invite code'),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _activateEmailController,
                                decoration: const InputDecoration(labelText: 'Email'),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _activatePasswordController,
                                obscureText: true,
                                decoration: const InputDecoration(labelText: 'Password'),
                              ),
                              const SizedBox(height: 16),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton(
                                  onPressed: _submitting ? null : _activate,
                                  child: const Text('Activate account'),
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text('Demo invite: ROHAN-START'),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (_error != null)
                      Text(
                        _error!,
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
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
