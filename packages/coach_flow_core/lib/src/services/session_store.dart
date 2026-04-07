import 'dart:convert';

import 'package:coach_flow_core/src/models/platform_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SessionStore {
  static const _sessionKey = 'coach_flow.session';

  Future<AuthSession?> loadSession() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_sessionKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }

    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return AuthSession.fromJson(decoded);
  }

  Future<void> saveSession(AuthSession session) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_sessionKey, jsonEncode(session.toJson()));
  }

  Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_sessionKey);
  }
}
