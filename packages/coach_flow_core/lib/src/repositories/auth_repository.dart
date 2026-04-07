import 'package:coach_flow_core/src/models/platform_models.dart';
import 'package:coach_flow_core/src/services/api_client.dart';
import 'package:coach_flow_core/src/services/session_store.dart';

class AuthRepository {
  const AuthRepository({
    required this.apiClient,
    required this.sessionStore,
  });

  final ApiClient apiClient;
  final SessionStore sessionStore;

  Future<AuthSession?> restoreSession() {
    return sessionStore.loadSession();
  }

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final response = await apiClient.postMap(
      '/api/auth/login',
      authenticated: false,
      body: {
        'email': email,
        'password': password,
      },
    );
    final session = AuthSession.fromJson(response);
    await sessionStore.saveSession(session);
    return session;
  }

  Future<AuthSession> activateClient({
    required String inviteCode,
    required String email,
    required String password,
  }) async {
    final response = await apiClient.postMap(
      '/api/auth/client/activate',
      authenticated: false,
      body: {
        'invite_code': inviteCode,
        'email': email,
        'password': password,
      },
    );
    final session = AuthSession.fromJson(response);
    await sessionStore.saveSession(session);
    return session;
  }

  Future<void> logout() {
    return sessionStore.clear();
  }
}
