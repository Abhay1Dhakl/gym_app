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

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _loginEmailController = TextEditingController(text: 'maya@example.com');
  final _loginPasswordController = TextEditingController(text: 'client12345');
  final _inviteCodeController = TextEditingController(text: 'ROHAN-START');
  final _activateEmailController = TextEditingController(
    text: 'rohan@example.com',
  );
  final _activatePasswordController = TextEditingController(
    text: 'client12345',
  );
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
      body: AuroraBackground(
        palette: AppTheme.clientPalette,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: GlassPanel(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const BrandChip(
                      label: 'Member App',
                      icon: Icons.fitness_center_rounded,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Your training space, nutrition targets, and coach communication in one place.',
                      style: Theme.of(context).textTheme.displaySmall,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Log in with your account or activate the invite your gym owner created for you.',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 24),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        dividerColor: Colors.transparent,
                        indicator: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        tabs: const [
                          Tab(text: 'Login'),
                          Tab(text: 'Activate'),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 320,
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          Column(
                            children: [
                              const SizedBox(height: 18),
                              TextField(
                                controller: _loginEmailController,
                                decoration: const InputDecoration(
                                  labelText: 'Email',
                                  prefixIcon: Icon(
                                    Icons.alternate_email_rounded,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _loginPasswordController,
                                obscureText: true,
                                decoration: const InputDecoration(
                                  labelText: 'Password',
                                  prefixIcon: Icon(Icons.lock_outline_rounded),
                                ),
                              ),
                              const SizedBox(height: 18),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton(
                                  onPressed: _submitting ? null : _login,
                                  child: const Text('Open my app'),
                                ),
                              ),
                              const SizedBox(height: 16),
                              const _HintPill(
                                label:
                                    'Demo client: maya@example.com / client12345',
                              ),
                            ],
                          ),
                          Column(
                            children: [
                              const SizedBox(height: 18),
                              TextField(
                                controller: _inviteCodeController,
                                decoration: const InputDecoration(
                                  labelText: 'Invite code',
                                  prefixIcon: Icon(
                                    Icons.confirmation_number_outlined,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _activateEmailController,
                                decoration: const InputDecoration(
                                  labelText: 'Email',
                                  prefixIcon: Icon(
                                    Icons.alternate_email_rounded,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _activatePasswordController,
                                obscureText: true,
                                decoration: const InputDecoration(
                                  labelText: 'Password',
                                  prefixIcon: Icon(Icons.lock_outline_rounded),
                                ),
                              ),
                              const SizedBox(height: 18),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton(
                                  onPressed: _submitting ? null : _activate,
                                  child: const Text('Activate account'),
                                ),
                              ),
                              const SizedBox(height: 16),
                              const _HintPill(
                                label: 'Demo invite: ROHAN-START',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (_error != null)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
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

class _HintPill extends StatelessWidget {
  const _HintPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF475569)),
      ),
    );
  }
}
