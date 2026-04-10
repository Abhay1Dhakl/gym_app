import 'dart:async';

import 'package:coach_flow_core/src/models/platform_models.dart';
import 'package:coach_flow_core/src/services/api_client.dart';
import 'package:coach_flow_core/src/services/message_stream_connection.dart';
import 'package:flutter/foundation.dart';

typedef ConversationLoader = Future<List<MessageItem>> Function();
typedef ConversationSender = Future<MessageItem> Function(String body);
typedef ConversationConnector = Future<MessageStreamConnection> Function();

class LiveConversationState {
  const LiveConversationState({
    this.messages = const <MessageItem>[],
    this.isLoading = false,
    this.isConnected = false,
    this.isSending = false,
    this.error,
  });

  final List<MessageItem> messages;
  final bool isLoading;
  final bool isConnected;
  final bool isSending;
  final String? error;

  bool get hasMessages => messages.isNotEmpty;

  LiveConversationState copyWith({
    List<MessageItem>? messages,
    bool? isLoading,
    bool? isConnected,
    bool? isSending,
    Object? error = _sentinel,
  }) {
    return LiveConversationState(
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      isConnected: isConnected ?? this.isConnected,
      isSending: isSending ?? this.isSending,
      error: identical(error, _sentinel) ? this.error : error as String?,
    );
  }

  static const Object _sentinel = Object();
}

class LiveConversationController extends ChangeNotifier {
  LiveConversationController({
    required ConversationLoader loadMessages,
    required ConversationSender sendMessage,
    required ConversationConnector connect,
  }) : _loadMessages = loadMessages,
       _sendMessage = sendMessage,
       _connect = connect;

  final ConversationLoader _loadMessages;
  final ConversationSender _sendMessage;
  final ConversationConnector _connect;

  LiveConversationState _state = const LiveConversationState(isLoading: true);
  LiveConversationState get state => _state;

  MessageStreamConnection? _connection;
  StreamSubscription<MessageItem>? _subscription;
  Timer? _reconnectTimer;
  bool _isDisposed = false;

  Future<void> start({List<MessageItem> seedMessages = const <MessageItem>[]}) async {
    final seeded = _sortedMessages(seedMessages);
    _state = _state.copyWith(
      messages: seeded,
      isLoading: seeded.isEmpty,
      error: null,
    );
    notifyListeners();

    try {
      final messages = await _loadMessages();
      if (_isDisposed) {
        return;
      }
      _state = _state.copyWith(
        messages: _sortedMessages(messages),
        isLoading: false,
        error: null,
      );
      notifyListeners();
    } catch (error) {
      if (_isDisposed) {
        return;
      }
      _state = _state.copyWith(
        isLoading: false,
        error: error.toString(),
      );
      notifyListeners();
    }

    await _attachLiveStream();
  }

  Future<void> refresh() async {
    try {
      final messages = await _loadMessages();
      if (_isDisposed) {
        return;
      }
      _state = _state.copyWith(
        messages: _sortedMessages(messages),
        isLoading: false,
        error: null,
      );
      notifyListeners();
    } catch (error) {
      if (_isDisposed) {
        return;
      }
      _state = _state.copyWith(error: error.toString());
      notifyListeners();
    }
  }

  Future<void> send(String rawBody) async {
    final body = rawBody.trim();
    if (body.isEmpty) {
      throw const ApiException('Message cannot be empty');
    }

    _state = _state.copyWith(isSending: true, error: null);
    notifyListeners();

    try {
      final message = await _sendMessage(body);
      if (_isDisposed) {
        return;
      }
      _upsertMessage(message);
      _state = _state.copyWith(isSending: false, error: null);
      notifyListeners();
    } catch (error) {
      if (_isDisposed) {
        return;
      }
      _state = _state.copyWith(isSending: false, error: error.toString());
      notifyListeners();
      rethrow;
    }
  }

  void clearError() {
    if (_state.error == null) {
      return;
    }
    _state = _state.copyWith(error: null);
    notifyListeners();
  }

  Future<void> _attachLiveStream() async {
    await _disposeConnection();
    _reconnectTimer?.cancel();

    try {
      final connection = await _connect();
      if (_isDisposed) {
        await connection.close();
        return;
      }

      _connection = connection;
      _subscription = connection.messages.listen(
        (message) {
          if (_isDisposed) {
            return;
          }
          _upsertMessage(message);
          _state = _state.copyWith(isConnected: true, error: null);
          notifyListeners();
        },
        onError: (Object error, StackTrace stackTrace) {
          if (_isDisposed) {
            return;
          }
          _state = _state.copyWith(
            isConnected: false,
            error: error.toString(),
          );
          notifyListeners();
          _scheduleReconnect();
        },
        onDone: () {
          if (_isDisposed) {
            return;
          }
          _state = _state.copyWith(isConnected: false);
          notifyListeners();
          _scheduleReconnect();
        },
        cancelOnError: true,
      );

      _state = _state.copyWith(isConnected: true, error: null);
      notifyListeners();
    } catch (error) {
      if (_isDisposed) {
        return;
      }
      _state = _state.copyWith(
        isConnected: false,
        error: error.toString(),
      );
      notifyListeners();
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 2), () {
      if (_isDisposed) {
        return;
      }
      _attachLiveStream();
    });
  }

  void _upsertMessage(MessageItem message) {
    final messages = List<MessageItem>.from(_state.messages);
    final index = messages.indexWhere((item) => item.id == message.id);
    if (index == -1) {
      messages.add(message);
    } else {
      messages[index] = message;
    }

    _state = _state.copyWith(messages: _sortedMessages(messages));
  }

  List<MessageItem> _sortedMessages(List<MessageItem> messages) {
    final unique = <int, MessageItem>{};
    for (final message in messages) {
      unique[message.id] = message;
    }
    final sorted = unique.values.toList()
      ..sort((left, right) => left.createdAt.compareTo(right.createdAt));
    return sorted;
  }

  Future<void> _disposeConnection() async {
    await _subscription?.cancel();
    _subscription = null;
    await _connection?.close();
    _connection = null;
  }

  @override
  void dispose() {
    _isDisposed = true;
    _reconnectTimer?.cancel();
    unawaited(_disposeConnection());
    super.dispose();
  }
}
