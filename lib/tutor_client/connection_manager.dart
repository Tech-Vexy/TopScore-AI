import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Connection states for the app
enum ConnectionState {
  connected,
  connecting,
  disconnected,
  reconnecting,
  offline, // No internet
}

/// Connection type for data usage optimization
enum ConnectionType {
  wifi,
  mobile,
  ethernet,
  unknown,
}

/// Manages connection state and provides retry logic
class ConnectionStateManager {
  static final ConnectionStateManager _instance =
      ConnectionStateManager._internal();
  factory ConnectionStateManager() => _instance;
  ConnectionStateManager._internal();

  final StreamController<ConnectionState> _stateController =
      StreamController<ConnectionState>.broadcast();

  ConnectionState _currentState = ConnectionState.disconnected;
  bool _hasInternet = true;
  StreamSubscription? _connectivitySubscription;

  // Data saver mode
  bool _dataSaverMode = false;
  ConnectionType _connectionType = ConnectionType.unknown;

  // Latency tracking
  int _latencyMs = 0;

  Stream<ConnectionState> get stateStream => _stateController.stream;
  ConnectionState get currentState => _currentState;
  bool get hasInternet => _hasInternet;
  bool get isConnected => _currentState == ConnectionState.connected;
  bool get dataSaverMode => _dataSaverMode;
  ConnectionType get connectionType => _connectionType;
  int get latencyMs => _latencyMs;

  /// Check if connection is metered (mobile data)
  bool get isMetered => _connectionType == ConnectionType.mobile;

  /// Initialize the connection state manager
  void initialize() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) {
      final hasConnection = results.any((r) => r != ConnectivityResult.none);
      _hasInternet = hasConnection;

      // Determine connection type
      if (results.contains(ConnectivityResult.wifi)) {
        _connectionType = ConnectionType.wifi;
      } else if (results.contains(ConnectivityResult.mobile)) {
        _connectionType = ConnectionType.mobile;
        // Auto-enable data saver on mobile
        _dataSaverMode = true;
        debugPrint('Mobile connection detected - Data Saver Mode enabled');
      } else if (results.contains(ConnectivityResult.ethernet)) {
        _connectionType = ConnectionType.ethernet;
      } else {
        _connectionType = ConnectionType.unknown;
      }

      if (!hasConnection) {
        _updateState(ConnectionState.offline);
      } else if (_currentState == ConnectionState.offline) {
        _updateState(ConnectionState.reconnecting);
      }
    });
  }

  void _updateState(ConnectionState newState) {
    if (_currentState != newState) {
      _currentState = newState;
      _stateController.add(newState);
      debugPrint('Connection state changed: $newState');
    }
  }

  void setConnected() => _updateState(ConnectionState.connected);
  void setConnecting() => _updateState(ConnectionState.connecting);
  void setDisconnected() => _updateState(ConnectionState.disconnected);
  void setReconnecting() => _updateState(ConnectionState.reconnecting);

  /// Toggle data saver mode manually
  void setDataSaverMode(bool enabled) {
    _dataSaverMode = enabled;
    debugPrint('Data Saver Mode: ${enabled ? "enabled" : "disabled"}');
  }

  /// Update latency measurement (called by WebSocket ping/pong)
  void updateLatency(int milliseconds) {
    _latencyMs = milliseconds;
  }

  /// Get connection quality based on latency
  ConnectionQuality getConnectionQuality() {
    if (_latencyMs < 100) return ConnectionQuality.excellent;
    if (_latencyMs < 300) return ConnectionQuality.good;
    if (_latencyMs < 500) return ConnectionQuality.fair;
    return ConnectionQuality.poor;
  }

  /// Check if large downloads should be allowed
  bool shouldAllowLargeDownloads() {
    return !_dataSaverMode || _connectionType == ConnectionType.wifi;
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    _stateController.close();
  }
}

/// Connection quality indicator
enum ConnectionQuality {
  excellent, // < 100ms
  good, // < 300ms
  fair, // < 500ms
  poor, // >= 500ms
}

/// Retry configuration
class RetryConfig {
  final int maxAttempts;
  final Duration initialDelay;
  final double backoffMultiplier;
  final Duration maxDelay;

  const RetryConfig({
    this.maxAttempts = 5,
    this.initialDelay = const Duration(milliseconds: 500),
    this.backoffMultiplier = 2.0,
    this.maxDelay = const Duration(seconds: 30),
  });

  Duration getDelay(int attempt) {
    final delay = initialDelay * (backoffMultiplier * attempt);
    return delay > maxDelay ? maxDelay : delay;
  }
}

/// Handles retry logic with exponential backoff
class RetryHandler<T> {
  final RetryConfig config;
  final Future<T> Function() operation;
  final bool Function(Object error)? shouldRetry;
  final void Function(int attempt, Object error)? onRetry;

  int _currentAttempt = 0;
  bool _cancelled = false;

  RetryHandler({
    required this.operation,
    this.config = const RetryConfig(),
    this.shouldRetry,
    this.onRetry,
  });

  /// Execute the operation with retry logic
  Future<T> execute() async {
    _cancelled = false;
    _currentAttempt = 0;

    while (!_cancelled) {
      try {
        _currentAttempt++;
        return await operation();
      } catch (error) {
        if (_cancelled) rethrow;

        final canRetry = shouldRetry?.call(error) ?? true;

        if (!canRetry || _currentAttempt >= config.maxAttempts) {
          rethrow;
        }

        onRetry?.call(_currentAttempt, error);

        final delay = config.getDelay(_currentAttempt);
        debugPrint(
          'Retry attempt $_currentAttempt after ${delay.inMilliseconds}ms',
        );

        await Future.delayed(delay);
      }
    }

    throw Exception('Retry cancelled');
  }

  void cancel() {
    _cancelled = true;
  }

  int get currentAttempt => _currentAttempt;
}

/// Message queue for offline support
class OfflineMessageQueue {
  static final OfflineMessageQueue _instance = OfflineMessageQueue._internal();
  factory OfflineMessageQueue() => _instance;
  OfflineMessageQueue._internal();

  final List<QueuedMessage> _queue = [];
  final StreamController<int> _queueSizeController =
      StreamController<int>.broadcast();

  Stream<int> get queueSizeStream => _queueSizeController.stream;
  int get queueSize => _queue.length;
  bool get hasQueuedMessages => _queue.isNotEmpty;

  /// Add a message to the queue
  void enqueue(QueuedMessage message) {
    _queue.add(message);
    _queueSizeController.add(_queue.length);
    debugPrint('Message queued. Queue size: ${_queue.length}');
  }

  /// Get all queued messages
  List<QueuedMessage> dequeueAll() {
    final messages = List<QueuedMessage>.from(_queue);
    _queue.clear();
    _queueSizeController.add(0);
    return messages;
  }

  /// Remove a specific message
  void remove(String messageId) {
    _queue.removeWhere((m) => m.id == messageId);
    _queueSizeController.add(_queue.length);
  }

  void dispose() {
    _queueSizeController.close();
  }
}

/// A message waiting to be sent
class QueuedMessage {
  final String id;
  final String content;
  final String userId;
  final String threadId;
  final DateTime queuedAt;
  final Map<String, dynamic>? extraData;

  QueuedMessage({
    required this.id,
    required this.content,
    required this.userId,
    required this.threadId,
    DateTime? queuedAt,
    this.extraData,
  }) : queuedAt = queuedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'content': content,
        'user_id': userId,
        'thread_id': threadId,
        'queued_at': queuedAt.toIso8601String(),
        'extra_data': extraData,
      };
}
