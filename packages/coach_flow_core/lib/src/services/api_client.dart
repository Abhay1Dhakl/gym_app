import 'dart:convert';

import 'package:coach_flow_core/src/services/session_store.dart';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({
    required this.baseUrl,
    required this.sessionStore,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  final String baseUrl;
  final SessionStore sessionStore;
  final http.Client _httpClient;

  Future<Map<String, dynamic>> getMap(String path, {bool authenticated = true}) async {
    final response = await _request('GET', path, authenticated: authenticated);
    if (response is! Map<String, dynamic>) {
      throw const ApiException('Unexpected response format');
    }
    return response;
  }

  Future<Map<String, dynamic>?> getOptionalMap(
    String path, {
    bool authenticated = true,
  }) async {
    final response = await _request('GET', path, authenticated: authenticated);
    if (response == null) {
      return null;
    }
    if (response is! Map<String, dynamic>) {
      throw const ApiException('Unexpected response format');
    }
    return response;
  }

  Future<List<dynamic>> getList(String path, {bool authenticated = true}) async {
    final response = await _request('GET', path, authenticated: authenticated);
    if (response is! List<dynamic>) {
      throw const ApiException('Unexpected response format');
    }
    return response;
  }

  Future<Uri> websocketUri(
    String path, {
    bool authenticated = true,
    Map<String, String>? queryParameters,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final params = <String, String>{
      ...uri.queryParameters,
      ...?queryParameters,
    };

    if (authenticated) {
      final session = await sessionStore.loadSession();
      if (session == null) {
        throw const ApiException('No active session');
      }
      params['access_token'] = session.accessToken;
    }

    return uri.replace(
      scheme: uri.scheme == 'https' ? 'wss' : 'ws',
      queryParameters: params,
    );
  }

  Future<Map<String, dynamic>> postMap(
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = true,
  }) async {
    final response = await _request('POST', path, body: body, authenticated: authenticated);
    if (response is! Map<String, dynamic>) {
      throw const ApiException('Unexpected response format');
    }
    return response;
  }

  Future<Map<String, dynamic>> putMap(
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = true,
  }) async {
    final response = await _request('PUT', path, body: body, authenticated: authenticated);
    if (response is! Map<String, dynamic>) {
      throw const ApiException('Unexpected response format');
    }
    return response;
  }

  Future<dynamic> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool authenticated = true,
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (authenticated) {
      final session = await sessionStore.loadSession();
      if (session == null) {
        throw const ApiException('No active session');
      }
      headers['Authorization'] = 'Bearer ${session.accessToken}';
    }

    final uri = Uri.parse('$baseUrl$path');
    late http.Response response;

    switch (method) {
      case 'GET':
        response = await _httpClient.get(uri, headers: headers).timeout(const Duration(seconds: 20));
        break;
      case 'POST':
        response = await _httpClient
            .post(uri, headers: headers, body: jsonEncode(body ?? const <String, dynamic>{}))
            .timeout(const Duration(seconds: 20));
        break;
      case 'PUT':
        response = await _httpClient
            .put(uri, headers: headers, body: jsonEncode(body ?? const <String, dynamic>{}))
            .timeout(const Duration(seconds: 20));
        break;
      default:
        throw ApiException('Unsupported method: $method');
    }

    if (response.statusCode >= 400) {
      throw ApiException(_extractError(response));
    }

    if (response.body.isEmpty) {
      return null;
    }

    return jsonDecode(response.body);
  }

  String _extractError(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic> && decoded['detail'] != null) {
        return decoded['detail'].toString();
      }
    } catch (_) {
      // Fall through.
    }

    return 'Request failed with status ${response.statusCode}';
  }
}
