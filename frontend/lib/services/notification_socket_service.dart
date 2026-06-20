import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../models/app_notification_model.dart';
import 'api_client.dart';
import 'token_storage.dart';

class NotificationSocketService {
  NotificationSocketService({
    required this.onNotification,
  });

  final ValueChanged<AppNotificationModel>
      onNotification;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;

  Timer? _pingTimer;
  Timer? _reconnectTimer;

  bool _isDisposed = false;
  bool _isConnecting = false;
  bool _isConnected = false;

  static const Duration _pingInterval = Duration(
    seconds: 25,
  );

  static const Duration _reconnectDelay = Duration(
    seconds: 3,
  );

  bool get isConnected => _isConnected;

  // ============================================================
  // CONNECT
  // ============================================================

  Future<void> connect() async {
    if (_isDisposed ||
        _isConnecting ||
        _isConnected) {
      return;
    }

    _isConnecting = true;

    try {
      final token =
          await TokenStorage.getToken();

      if (_isDisposed) {
        return;
      }

      if (token == null ||
          token.trim().isEmpty) {
        _scheduleReconnect();
        return;
      }

      final uri = _buildWebSocketUri(
        token: token.trim(),
      );

      final channel =
          WebSocketChannel.connect(
        uri,
      );

      _channel = channel;

      try {
        await channel.ready;
      } catch (_) {
        if (_channel == channel) {
          _channel = null;
        }

        await _closeChannelSilently(
          channel,
        );

        _scheduleReconnect();
        return;
      }

      if (_isDisposed) {
        await _closeChannelSilently(
          channel,
        );
        return;
      }

      _isConnected = true;

      _subscription = channel.stream.listen(
        _handleSocketData,
        onError: (_) {
          _handleConnectionLost();
        },
        onDone: _handleConnectionLost,
        cancelOnError: true,
      );

      _startPingTimer();
    } catch (_) {
      _scheduleReconnect();
    } finally {
      _isConnecting = false;
    }
  }

  // ============================================================
  // URI
  // ============================================================

  Uri _buildWebSocketUri({
    required String token,
  }) {
    final baseUrl =
        ApiClient.dio.options.baseUrl;

    final httpUri = Uri.parse(
      baseUrl,
    );

    final websocketScheme =
        httpUri.scheme == 'https'
            ? 'wss'
            : 'ws';

    final normalizedBasePath =
        httpUri.path.endsWith('/')
            ? httpUri.path.substring(
                0,
                httpUri.path.length - 1,
              )
            : httpUri.path;

    final socketPath =
        '$normalizedBasePath/notifications/ws';

    return httpUri.replace(
      scheme: websocketScheme,
      path: socketPath,
      queryParameters: {
        'token': token,
      },
    );
  }

  // ============================================================
  // INCOMING EVENTS
  // ============================================================

  void _handleSocketData(
    dynamic rawData,
  ) {
    if (_isDisposed) {
      return;
    }

    try {
      final decoded = _decodeData(
        rawData,
      );

      if (decoded == null) {
        return;
      }

      final eventType =
          decoded['type'];

      if (eventType == 'connected' ||
          eventType == 'pong') {
        return;
      }

      if (eventType !=
          'new_notification') {
        return;
      }

      final notificationData =
          decoded['notification'];

      if (notificationData is! Map) {
        return;
      }

      final notification =
          AppNotificationModel.fromJson(
        Map<String, dynamic>.from(
          notificationData,
        ),
      );

      if (notification.id == null ||
          notification.conversationId ==
              null) {
        return;
      }

      onNotification(
        notification,
      );
    } catch (_) {
    }
  }

  Map<String, dynamic>? _decodeData(
    dynamic rawData,
  ) {
    dynamic decoded;

    if (rawData is String) {
      decoded = jsonDecode(
        rawData,
      );
    } else if (rawData is List<int>) {
      decoded = jsonDecode(
        utf8.decode(
          rawData,
        ),
      );
    } else if (rawData is Map) {
      decoded = rawData;
    } else {
      return null;
    }

    if (decoded
        is Map<String, dynamic>) {
      return decoded;
    }

    if (decoded is Map) {
      return Map<String, dynamic>.from(
        decoded,
      );
    }

    return null;
  }

  // ============================================================
  // PING
  // ============================================================

  void _startPingTimer() {
    _pingTimer?.cancel();

    _pingTimer = Timer.periodic(
      _pingInterval,
      (_) {
        final channel = _channel;

        if (_isDisposed ||
            !_isConnected ||
            channel == null) {
          return;
        }

        try {
          channel.sink.add(
            'ping',
          );
        } catch (_) {
          _handleConnectionLost();
        }
      },
    );
  }

  // ============================================================
  // RECONNECT
  // ============================================================

  void _handleConnectionLost() {
    if (_isDisposed) {
      return;
    }

    _isConnected = false;

    _pingTimer?.cancel();
    _pingTimer = null;

    _subscription?.cancel();
    _subscription = null;

    final channel = _channel;
    _channel = null;

    if (channel != null) {
      _closeChannelSilently(
        channel,
      );
    }

    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_isDisposed) {
      return;
    }

    _reconnectTimer?.cancel();

    _reconnectTimer = Timer(
      _reconnectDelay,
      () {
        if (_isDisposed) {
          return;
        }

        connect();
      },
    );
  }

  // ============================================================
  // DISCONNECT
  // ============================================================

  Future<void> disconnect() async {
    _isConnected = false;

    _pingTimer?.cancel();
    _pingTimer = null;

    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    await _subscription?.cancel();
    _subscription = null;

    final channel = _channel;
    _channel = null;

    if (channel != null) {
      await _closeChannelSilently(
        channel,
      );
    }
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  Future<void> dispose() async {
    if (_isDisposed) {
      return;
    }

    _isDisposed = true;

    await disconnect();
  }

  Future<void> _closeChannelSilently(
    WebSocketChannel channel,
  ) async {
    try {
      await channel.sink.close();
    } catch (_) {
    }
  }
}