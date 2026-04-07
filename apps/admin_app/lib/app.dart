import 'package:coach_flow_core/coach_flow_core.dart';
import 'package:flutter/material.dart';

import 'screens/admin_shell.dart';
import 'screens/login_screen.dart';

class AdminApp extends StatefulWidget {
  const AdminApp({super.key});

  @override
  State<AdminApp> createState() => _AdminAppState();
}

class _AdminAppState extends State<AdminApp> {
  late final SessionStore _sessionStore;
  late final ApiClient _apiClient;
  late final AuthRepository _authRepository;
  late final AdminRepository _adminRepository;
  late Future<AuthSession?> _sessionFuture;

  @override
  void initState() {
    super.initState();
    _sessionStore = SessionStore();
    _apiClient = ApiClient(baseUrl: ApiConfig.resolveBaseUrl(), sessionStore: _sessionStore);
    _authRepository = AuthRepository(apiClient: _apiClient, sessionStore: _sessionStore);
    _adminRepository = AdminRepository(apiClient: _apiClient);
    _sessionFuture = _authRepository.restoreSession();
  }

  void _handleAuthenticated(AuthSession session) {
    setState(() {
      _sessionFuture = Future<AuthSession?>.value(session);
    });
  }

  Future<void> _handleLogout() async {
    await _authRepository.logout();
    if (!mounted) {
      return;
    }
    setState(() {
      _sessionFuture = Future<AuthSession?>.value(null);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Abhay Method Admin',
      theme: AppTheme.adminTheme(),
      debugShowCheckedModeBanner: false,
      home: FutureBuilder<AuthSession?>(
        future: _sessionFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }

          final session = snapshot.data;
          if (session != null && session.role == 'admin') {
            return AdminShell(
              adminRepository: _adminRepository,
              authRepository: _authRepository,
              onLogout: _handleLogout,
            );
          }

          return LoginScreen(
            authRepository: _authRepository,
            onAuthenticated: _handleAuthenticated,
          );
        },
      ),
    );
  }
}
