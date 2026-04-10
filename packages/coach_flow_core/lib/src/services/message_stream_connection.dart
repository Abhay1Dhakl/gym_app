import 'dart:async';
import 'dart:convert';

import 'package:coach_flow_core/src/models/platform_models.dart';
import 'package:coach_flow_core/src/services/api_client.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class MessageStreamConnection {
  MessageStreamConnection._({
    required WebSocketChannel channel,
    required Timer pingTimer,
  }) : _channel = channel,
       _pingTimer = pingTimer;

  final WebSocketChannel _channel;
  final Timer _pingTimer;

  Stream<MessageItem> get messages => _channel.stream.map((event) {
    final decoded = event is String ? jsonDecode(event) : event;
    if (decoded is! Map<String, dynamic>) {
      throw const ApiException('Unexpected websocket payload');
    }
    return MessageItem.fromJson(decoded);
  });

  static Future<MessageStreamConnection> connect({
    required ApiClient apiClient,
    required String path,
  }) async {
    final uri = await apiClient.websocketUri(path);
    final channel = WebSocketChannel.connect(uri);
    final pingTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      try {
        channel.sink.add('ping');
      } catch (_) {
        // The reconnect loop owns lifecycle recovery.
      }
    });

    return MessageStreamConnection._(channel: channel, pingTimer: pingTimer);
  }

  Future<void> close() async {
    _pingTimer.cancel();
    await _channel.sink.close();
  }
}
