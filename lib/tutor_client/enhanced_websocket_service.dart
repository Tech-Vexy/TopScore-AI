import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';

import 'connection_manager.dart';
import 'offline_storage.dart';
import 'audio_playback_queue.dart';

/// Enhanced WebSocket Service with retry logic, offline support, and audio queue
class EnhancedWebSocketService {
  WebSocketChannel? _channel;
  WebSocketChannel? _voiceChannel; // Dedicated channel for Gemini Native Audio
  final StreamController<Map<String, dynamic>> _messageController =
      StreamController.broadcast();
  final StreamController<bool> _isConnectedController =
      StreamController.broadcast();

  bool _isConnected = false;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  Timer? _reconnectTimer;
  Timer? _keepAliveTimer;

  // NEW: Connection manager for state tracking and retry logic
  final ConnectionStateManager _connectionManager = ConnectionStateManager();

  // NEW: Offline storage for message caching
  final OfflineStorage _offlineStorage = OfflineStorage();
  final OfflineSyncManager _syncManager = OfflineSyncManager();

  // NEW: Audio playback queue for voice responses
  final AudioPlaybackQueue _audioQueue = AudioPlaybackQueue();

  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;
  Stream<bool> get isConnectedStream => _isConnectedController.stream;
  Stream<ConnectionState> get connectionStateStream =>
      _connectionManager.stateStream;
  Stream<AudioQueueState> get audioStateStream => _audioQueue.stateStream;

  bool get isConnected => _isConnected;
  ConnectionState get connectionState => _connectionManager.currentState;
  bool get hasInternet => _connectionManager.hasInternet;

  final String userId;
  String sessionId = const Uuid().v4();
  String threadId = const Uuid().v4();

  EnhancedWebSocketService({required this.userId}) {
    _initialize();
  }

  Future<void> _initialize() async {
    _connectionManager.initialize();
    await _offlineStorage.initialize();
    await _syncManager.initialize();

    // Listen for connectivity changes
    _connectionManager.stateStream.listen((state) {
      if (state == ConnectionState.reconnecting && hasInternet) {
        // Try to reconnect and sync pending messages
        connect();
      }
    });
  }

  String get _host {
    return 'agent.topscoreapp.ai';
  }

  String get _wsUrl => 'wss://$_host/ws/chat/$sessionId?user_id=$userId';
  String get _geminiVoiceWsUrl => 'wss://$_host/voice/ws/gemini/$sessionId';

  void setThreadId(String newThreadId) => threadId = newThreadId;
  void setSessionId(String newSessionId) => sessionId = newSessionId;

  /// Connect with automatic retry and offline fallback
  Future<void> connect() async {
    // Guard: Prevent duplicate connections
    if (_isConnected && _channel != null) {
      debugPrint('WebSocket: Already connected');
      return;
    }

    if (_reconnectAttempts >= _maxReconnectAttempts) {
      debugPrint('WebSocket: Max reconnect attempts reached');
      _connectionManager.setDisconnected();
      return;
    }

    if (!hasInternet) {
      debugPrint('WebSocket: No internet, will connect when available');
      _connectionManager.setDisconnected();
      return;
    }

    _connectionManager.setConnecting();

    try {
      debugPrint(
        'WebSocket: Connecting to $_wsUrl (attempt ${_reconnectAttempts + 1})',
      );
      _channel = WebSocketChannel.connect(Uri.parse(_wsUrl));

      _channel!.stream.listen(
        (message) {
          debugPrint(
            '📥 Raw WS message received: ${message.toString().substring(0, message.toString().length > 150 ? 150 : message.toString().length)}...',
          );
          try {
            final data = jsonDecode(message) as Map<String, dynamic>;
            _handleIncomingMessage(data);
          } catch (e) {
            debugPrint('WebSocket: Error parsing message: $e');
          }
        },
        onError: (error) {
          debugPrint('WebSocket: Connection error: $error');
          _handleDisconnection();
        },
        onDone: () {
          debugPrint('WebSocket: Connection closed');
          _handleDisconnection();
        },
      );
    } catch (e) {
      debugPrint('WebSocket: Failed to connect: $e');
      _isConnected = false;
      _isConnectedController.add(false);
      _connectionManager.setDisconnected();
      _scheduleReconnect();
    }
  }

  void _handleIncomingMessage(Map<String, dynamic> data) {
    final type = data['type'];
    debugPrint(
      '🔵 WS Service received: type=$type, data=${data.toString().substring(0, data.toString().length > 200 ? 200 : data.toString().length)}',
    );

    switch (type) {
      case 'connected':
        debugPrint('WebSocket: Connected - Session ID: ${data['session_id']}');
        _isConnected = true;
        _reconnectAttempts = 0;
        _isConnectedController.add(true);
        _connectionManager.setConnected();
        _startKeepAliveTimer();

        // Sync pending messages when connected
        _syncPendingMessages();
        break;

      case 'ping':
        _sendPong();
        break;

      case 'response':
        // Handle audio in voice responses
        if (data['audio'] != null) {
          _audioQueue.enqueueBase64(
            data['audio'],
            mimeType: data['audio_mime_type'] ?? 'audio/wav',
            id: data['message_id'],
          );
        }

        // Cache the message
        _cacheMessage(data);
        _messageController.add(data);
        break;

      default:
        debugPrint('🔸 WS Service forwarding message type: $type');
        _messageController.add(data);
    }
  }

  /// Send message with offline fallback
  Future<void> sendMessage({
    required String message,
    required String userId,
    String? threadId,
    String? modelPreference,
    String? fileUrl,
    String? fileType,
    String? audioData,
    Map<String, dynamic>? extraData,
  }) async {
    final messageId = const Uuid().v4();
    final targetThreadId = threadId ?? this.threadId;

    final data = {
      "type": "message",
      "message_id": messageId,
      "message": message,
      "user_id": userId,
      "thread_id": targetThreadId,
      "model_preference": modelPreference ?? "smart",
      "timestamp": DateTime.now().millisecondsSinceEpoch,
      if (fileUrl != null) 'file_url': fileUrl,
      if (fileType != null) 'file_type': fileType,
      if (audioData != null) 'audio_data': audioData,
      ...?extraData,
    };

    // If not connected, queue the message for later
    if (!_isConnected || _channel == null) {
      await _offlineStorage.savePendingMessage(
        PendingMessage(
          id: messageId,
          threadId: targetThreadId,
          userId: userId,
          content: message,
          createdAt: DateTime.now(),
          extraData: data,
        ),
      );

      debugPrint('Message queued for later: $messageId');

      // Still emit it locally for UI
      _messageController.add({
        'type': 'queued',
        'message_id': messageId,
        'message': message,
        'pending': true,
      });
      return;
    }

    try {
      final jsonData = jsonEncode(data);
      debugPrint(
        '📤 WS Service sending: ${jsonData.substring(0, jsonData.length > 300 ? 300 : jsonData.length)}...',
      );
      _channel!.sink.add(jsonData);
      debugPrint('✅ WS Service message sent successfully');
    } catch (e) {
      debugPrint('❌ Error sending message: $e');
      // Queue if send failed
      await _offlineStorage.savePendingMessage(
        PendingMessage(
          id: messageId,
          threadId: targetThreadId,
          userId: userId,
          content: message,
          createdAt: DateTime.now(),
          extraData: data,
        ),
      );
    }
  }

  /// Connect to Gemini Native Audio WebSocket
  Future<void> connectVoice() async {
    if (_voiceChannel != null) return;

    try {
      debugPrint('Voice WebSocket: Connecting to $_geminiVoiceWsUrl');
      _voiceChannel = WebSocketChannel.connect(Uri.parse(_geminiVoiceWsUrl));

      _voiceChannel!.stream.listen(
        (message) {
          try {
            final data = jsonDecode(message) as Map<String, dynamic>;
            _handleIncomingMessage(data);
          } catch (e) {
            debugPrint('Voice WebSocket: Error parsing message: $e');
          }
        },
        onError: (error) {
          debugPrint('Voice WebSocket: Connection error: $error');
          _voiceChannel = null;
        },
        onDone: () {
          debugPrint('Voice WebSocket: Connection closed');
          _voiceChannel = null;
        },
      );
    } catch (e) {
      debugPrint('Voice WebSocket: Failed to connect: $e');
    }
  }

  /// Connect to Gemini Native Audio WebSocket
  Future<void> connectGeminiVoice() async {
    // Guard: Prevent duplicate voice connections
    if (_voiceChannel != null) {
      debugPrint('Voice WebSocket: Already connected');
      return;
    }

    try {
      debugPrint('WebSocket: Connecting to Gemini Voice $_geminiVoiceWsUrl');
      _voiceChannel = WebSocketChannel.connect(Uri.parse(_geminiVoiceWsUrl));

      _voiceChannel!.stream.listen(
        (message) {
          try {
            final data = jsonDecode(message) as Map<String, dynamic>;
            _handleIncomingMessage(data);
          } catch (e) {
            debugPrint('Voice WebSocket: Error parsing message: $e');
          }
        },
        onError: (error) {
          debugPrint('Voice WebSocket: Connection error: $error');
          _voiceChannel = null;
        },
        onDone: () {
          debugPrint('Voice WebSocket: Connection closed');
          _voiceChannel = null;
        },
      );
    } catch (e) {
      debugPrint('Voice WebSocket: Failed to connect: $e');
      _voiceChannel = null;
    }
  }

  /// Disconnect Gemini Voice session
  void disconnectVoice() {
    if (_voiceChannel != null) {
      _voiceChannel!.sink.close();
      _voiceChannel = null;
      debugPrint('Voice WebSocket: Disconnected');
    }
    // Clear audio queue on disconnect
    _audioQueue.clearQueue();
  }

  /// Send audio data to Gemini Native Audio
  void sendAudio(String base64Audio) {
    if (_voiceChannel != null) {
      final data = {
        "type": "audio",
        "audio_data": base64Audio,
        "user_id": userId,
        "mime_type": "audio/webm", // Adjust based on recording format
        "timestamp": DateTime.now().millisecondsSinceEpoch,
      };
      _voiceChannel!.sink.add(jsonEncode(data));
    } else {
      debugPrint('Voice WebSocket: Not connected, cannot send audio');
    }
  }

  /// Send text message specifically to Voice channel (TTS)
  void sendVoiceText(String text, {String voice = "Aoede"}) {
    if (_voiceChannel != null) {
      final data = {
        "type": "text",
        "message": text,
        "voice": voice,
        "timestamp": DateTime.now().millisecondsSinceEpoch,
      };
      _voiceChannel!.sink.add(jsonEncode(data));
    }
  }

  /// Sync pending messages when connection is restored
  Future<void> _syncPendingMessages() async {
    if (!_isConnected) return;

    final result = await _syncManager.syncPendingMessages(
      sendMessage: (pending) async {
        try {
          final data =
              pending.extraData ??
              {
                "type": "message",
                "message_id": pending.id,
                "message": pending.content,
                "user_id": pending.userId,
                "thread_id": pending.threadId,
                "timestamp": pending.createdAt.millisecondsSinceEpoch,
              };
          _channel!.sink.add(jsonEncode(data));
          return true;
        } catch (e) {
          return false;
        }
      },
    );

    if (result.synced > 0) {
      debugPrint('Synced ${result.synced} pending messages');
      _messageController.add({
        'type': 'sync_complete',
        'synced': result.synced,
        'failed': result.failed,
      });
    }
  }

  /// Cache a message locally
  Future<void> _cacheMessage(Map<String, dynamic> data) async {
    final id = data['message_id'] ?? const Uuid().v4();
    final content = data['content'] ?? data['message'] ?? '';
    final role = data['role'] ?? 'assistant';

    await _offlineStorage.cacheMessage(
      CachedMessage(
        id: id,
        threadId: threadId,
        content: content,
        role: role,
        timestamp: DateTime.now(),
        synced: true,
      ),
    );
  }

  /// Get cached messages for offline display
  Future<List<CachedMessage>> getCachedMessages() async {
    return _offlineStorage.getCachedMessages(threadId);
  }

  /// Get pending messages count
  Future<int> getPendingMessagesCount() async {
    final pending = await _offlineStorage.getPendingMessages();
    return pending.length;
  }

  // Audio queue controls
  void pauseAudio() => _audioQueue.pause();
  void resumeAudio() => _audioQueue.resume();
  void skipAudio() => _audioQueue.skip();
  void clearAudioQueue() => _audioQueue.clearQueue();

  void _sendPong() {
    if (_channel != null && _isConnected) {
      _channel!.sink.add(jsonEncode({'type': 'pong'}));
    }
  }

  void _startKeepAliveTimer() {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (_isConnected && _channel != null) {
        try {
          _channel!.sink.add(jsonEncode({'type': 'ping'}));
        } catch (e) {
          debugPrint('Keep-alive failed: $e');
          _handleDisconnection();
        }
      } else {
        _keepAliveTimer?.cancel();
      }
    });
  }

  void _scheduleReconnect() {
    _reconnectAttempts++;
    if (_reconnectAttempts < _maxReconnectAttempts) {
      final backoffSeconds = _reconnectAttempts * 2;
      debugPrint('WebSocket: Retrying in $backoffSeconds seconds...');
      _connectionManager.setReconnecting();
      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(Duration(seconds: backoffSeconds), connect);
    } else {
      _connectionManager.setDisconnected();
    }
  }

  void _handleDisconnection() {
    _isConnected = false;
    _isConnectedController.add(false);
    _connectionManager.setDisconnected();
    _scheduleReconnect();
  }

  void resetConnection() {
    _reconnectAttempts = 0;
    _reconnectTimer?.cancel();
    _keepAliveTimer?.cancel();
    connect();
  }

  /// Send audio message using Gemini Native Audio (speech-to-speech)
  /// This provides end-to-end voice conversation with audio input AND output
  ///
  /// The server will respond with:
  /// - type: 'response'
  /// - text: The text transcription/response
  /// - audio: Base64-encoded audio response (to play back)
  /// - audio_mime_type: MIME type of the audio (usually 'audio/wav')
  /// - latency: Processing time in seconds
  void sendGeminiAudioMessage({
    required String base64Audio,
    String mimeType = 'audio/webm',
  }) async {
    if (_voiceChannel == null) {
      await connectVoice();
      if (_voiceChannel == null) {
        debugPrint('Gemini Voice WS Not connected');
        return;
      }
    }

    final Map<String, dynamic> data = {
      "type": "audio",
      "audio_data": base64Audio,
      "user_id": userId,
      "mime_type": mimeType,
    };

    debugPrint('Sending Gemini Audio Payload (${base64Audio.length} chars)');
    _voiceChannel!.sink.add(jsonEncode(data));
  }

  /// Send text message for TTS using Gemini Native Audio
  /// Server will respond with synthesized audio
  void sendGeminiTextForSpeech({
    required String text,
    String voice = 'Aoede',
  }) async {
    if (_voiceChannel == null) {
      await connectVoice();
      if (_voiceChannel == null) {
        debugPrint('Gemini Voice WS Not connected');
        return;
      }
    }

    final Map<String, dynamic> data = {
      "type": "text",
      "message": text,
      "voice": voice,
    };

    debugPrint(
      'Sending Gemini TTS request: ${text.substring(0, text.length > 50 ? 50 : text.length)}...',
    );
    _voiceChannel!.sink.add(jsonEncode(data));
  }

  Future<void> dispose() async {
    _reconnectTimer?.cancel();
    _keepAliveTimer?.cancel();
    _channel?.sink.close();
    _voiceChannel?.sink.close();
    _messageController.close();
    _isConnectedController.close();
    _connectionManager.dispose();
    await _audioQueue.dispose();
  }
}
