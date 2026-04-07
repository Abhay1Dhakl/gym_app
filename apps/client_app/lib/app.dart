import 'package:coach_flow_core/coach_flow_core.dart';
import 'package:flutter/material.dart';

import 'screens/auth_screen.dart';
import 'screens/client_shell.dart';

class ClientApp extends StatefulWidget {
  const ClientApp({super.key});

  @override
  State<ClientApp> createState() => _ClientAppState();
}

class _ClientAppState extends State<ClientApp> {
  late final SessionStore _sessionStore;
  late final ApiClient _apiClient;
  late final AuthRepository _authRepository;
  late final ClientRepository _clientRepository;
  late Future<AuthSession?> _sessionFuture;

  @override
  void initState() {
    super.initState();
    _sessionStore = SessionStore();
    _apiClient = ApiClient(baseUrl: ApiConfig.resolveBaseUrl(), sessionStore: _sessionStore);
    _authRepository = AuthRepository(apiClient: _apiClient, sessionStore: _sessionStore);
    _clientRepository = ClientRepository(apiClient: _apiClient);
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
      title: 'Abhay Method Client',
      theme: AppTheme.clientTheme(),
      debugShowCheckedModeBanner: false,
      home: FutureBuilder<AuthSession?>(
        future: _sessionFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }

          final session = snapshot.data;
          if (session != null && session.role == 'client') {
            return ClientShell(
              clientRepository: _clientRepository,
              onLogout: _handleLogout,
            );
          }

          return AuthScreen(
            authRepository: _authRepository,
            onAuthenticated: _handleAuthenticated,
          );
        },
      ),
    );
  }
}
