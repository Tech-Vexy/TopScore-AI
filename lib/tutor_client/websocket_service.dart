import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/widgets.dart';
import 'connection_manager.dart';

class WebSocketService with WidgetsBindingObserver {
  WebSocketChannel? _channel;
  WebSocketChannel? _voiceChannel; // Dedicated channel for voice
  final StreamController<Map<String, dynamic>> _messageController =
      StreamController.broadcast();
  final StreamController<bool> _isConnectedController =
      StreamController.broadcast();

  bool _isConnected = false;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 3;
  Timer? _reconnectTimer;
  Timer? _pingTimer;
  Timer? _keepAliveTimer;

  // Lifecycle state tracking
  bool _wasDisconnectedDueToBackground = false;
  final List<Map<String, dynamic>> _queuedMessages =
      []; // Message queue for reconnection

  // Latency tracking
  DateTime? _lastPingSentAt;
  final ConnectionStateManager _connectionManager = ConnectionStateManager();

  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;
  Stream<bool> get isConnectedStream => _isConnectedController.stream;
  bool get isConnected => _isConnected;

  final String userId;
  String sessionId = const Uuid().v4(); // Session ID for WebSocket path
  String threadId = const Uuid().v4(); // Thread ID for chat history
  String? studentName;
  String? academicLevel;

  WebSocketService({required this.userId});

  // --- PRODUCTION BACKEND ONLY ---

  String get _host => 'agent.topscoreapp.ai';
  String get _protocolHttp => 'https';
  String get _protocolWs => 'wss';

  // Base URL
  String get _baseUrl => '$_protocolHttp://$_host';

  // WebSocket URLs
  String get _wsUrl => '$_protocolWs://$_host/ws/chat/$sessionId';

  String get _voiceWsUrl => '$_protocolWs://$_host/voice/ws/live/$sessionId';

  /// Gemini Native Audio WebSocket endpoint
  String get _geminiVoiceWsUrl =>
      '$_protocolWs://$_host/voice/ws/gemini/$sessionId';

  // ---------------------------------

  void setThreadId(String newThreadId) {
    threadId = newThreadId;
  }

  void setSessionId(String newSessionId) {
    sessionId = newSessionId;
  }

  void setStudentInfo({String? name, String? level}) {
    studentName = name;
    academicLevel = level;
  }

  /// Initialize lifecycle listener to handle app backgrounding
  /// Call this once during app initialization
  void initLifecycleListener() {
    WidgetsBinding.instance.addObserver(this);
    debugPrint('WebSocket: Lifecycle listener initialized');
  }

  /// Handle app lifecycle state changes
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint('WebSocket: App lifecycle changed to $state');

    switch (state) {
      case AppLifecycleState.resumed:
        // App came back to foreground
        debugPrint('WebSocket: App resumed - verifying connection...');
        if (!_isConnected) {
          debugPrint(
              'WebSocket: Connection lost while backgrounded, reconnecting silently...');
          _wasDisconnectedDueToBackground = true;
          _reconnectAttempts = 0; // Reset attempts for seamless reconnect
          connect();
        }
        break;

      case AppLifecycleState.paused:
        // App went to background
        debugPrint('WebSocket: App backgrounded - connection may drop');
        break;

      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        // App is transitioning or being terminated
        break;
    }
  }

  /// DEPRECATED: Use Firebase Realtime Database directly
  /// This endpoint no longer exists in the backend
  @Deprecated('Use Firebase RTDB to fetch threads from chats/{user_id}')
  Future<List<Map<String, dynamic>>> fetchThreads() async {
    debugPrint('WARNING: fetchThreads() is deprecated. Use Firebase RTDB.');
    return [];
  }

  /// DEPRECATED: Use Firebase Realtime Database directly
  /// This endpoint no longer exists in the backend
  @Deprecated(
    'Use Firebase RTDB to fetch messages from chats/{thread_id}/messages',
  )
  Future<List<Map<String, dynamic>>> fetchMessages(String threadId) async {
    debugPrint('WARNING: fetchMessages() is deprecated. Use Firebase RTDB.');
    return [];
  }

  /// Delete a specific message from the thread
  Future<bool> deleteMessage({
    required String threadId,
    required String messageId,
  }) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/threads/$threadId/messages/$messageId'),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error deleting message: $e');
      return false;
    }
  }

  /// Update message content and optionally regenerate AI response
  Future<bool> updateMessage({
    required String threadId,
    required String messageId,
    String? newContent,
    bool regenerate = false,
    String? modelPreference,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/threads/$threadId/messages/$messageId'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          if (newContent != null) 'content': newContent,
          'regenerate': regenerate,
          'user_id': userId,
          'session_id': sessionId, // Required for streaming response
          if (modelPreference != null) 'model_preference': modelPreference,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error updating message: $e');
      return false;
    }
  }

  /// Transcribe audio file using Groq Whisper (server-side STT)
  /// @deprecated Use transcribeAudioGemini for better quality
  Future<String?> transcribeAudio(String audioFilePath) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/voice/transcribe'),
      );
      request.files.add(
        await http.MultipartFile.fromPath('file', audioFilePath),
      );

      final response = await request.send();
      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        final json = jsonDecode(responseData);
        return json['text'];
      }
    } catch (e) {
      debugPrint('Error transcribing audio: $e');
    }
    return null;
  }

  /// Transcribe audio using Gemini 2.5 Flash Native Audio
  /// Higher quality transcription using the native audio model
  Future<String?> transcribeAudioGemini(String audioFilePath) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/voice/gemini/transcribe'),
      );
      request.files.add(
        await http.MultipartFile.fromPath('file', audioFilePath),
      );

      final response = await request.send();
      if (response.statusCode == 200) {
        final responseData = await response.stream.bytesToString();
        final json = jsonDecode(responseData);
        return json['text'];
      }
    } catch (e) {
      debugPrint('Error transcribing audio with Gemini: $e');
    }
    return null;
  }

  /// Text-to-Speech using Gemini 2.5 Flash Native Audio
  /// Returns base64-encoded audio or null on failure
  Future<Map<String, dynamic>?> textToSpeechGemini(
    String text, {
    String voice = 'Aoede',
  }) async {
    try {
      final response = await http.post(
        Uri.parse(
          '$_baseUrl/voice/gemini/speak?text=${Uri.encodeComponent(text)}&voice=$voice',
        ),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      debugPrint('Error with Gemini TTS: $e');
    }
    return null;
  }

  Future<bool> sendFeedback({
    required String threadId,
    required String messageId,
    required int? feedback,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/threads/$threadId/messages/$messageId/feedback'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'feedback': feedback}),
      );
      if (response.statusCode == 200) {
        return true;
      }
    } catch (e) {
      // Error sending feedback
    }
    return false;
  }

  void connect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      debugPrint(
        'WebSocket: Max reconnect attempts reached. Call resetConnection() to retry.',
      );
      return;
    }

    try {
      final isQuietReconnect = _wasDisconnectedDueToBackground;
      debugPrint(
        'WebSocket: ${isQuietReconnect ? "Quietly reconnecting" : "Connecting"} to $_wsUrl (attempt ${_reconnectAttempts + 1}/$_maxReconnectAttempts)',
      );
      _channel = WebSocketChannel.connect(Uri.parse(_wsUrl));

      _channel!.stream.listen(
        (message) {
          try {
            final data = jsonDecode(message) as Map<String, dynamic>;
            _handleIncomingMessage(data);

            // If this is the 'connected' response and we have queued messages, send them
            if (data['type'] == 'connected' && _queuedMessages.isNotEmpty) {
              debugPrint(
                  'WebSocket: Sending ${_queuedMessages.length} queued messages...');
              for (final queuedMsg in _queuedMessages) {
                _channel?.sink.add(jsonEncode(queuedMsg));
              }
              _queuedMessages.clear();
              _wasDisconnectedDueToBackground = false;
            }
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

      // Connection will be confirmed when we receive 'connected' message
    } catch (e) {
      debugPrint('WebSocket: Failed to connect: $e');
      _isConnected = false;
      _isConnectedController.add(false);
      _scheduleReconnect();
    }
  }

  /// Connect to dedicated voice WebSocket endpoint for live voice mode
  /// @deprecated Use connectGeminiVoice for better quality
  void connectVoice() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      debugPrint(
        'Voice WebSocket: Max reconnect attempts reached. Call resetConnection() to retry.',
      );
      return;
    }

    try {
      debugPrint(
        'Voice WebSocket: Connecting to $_voiceWsUrl (attempt ${_reconnectAttempts + 1}/$_maxReconnectAttempts)',
      );
      _channel = WebSocketChannel.connect(Uri.parse(_voiceWsUrl));

      _channel!.stream.listen(
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
          _handleDisconnection();
        },
        onDone: () {
          debugPrint('Voice WebSocket: Connection closed');
          _handleDisconnection();
        },
      );

      // Connection will be confirmed when we receive 'connected' message
    } catch (e) {
      debugPrint('Voice WebSocket: Failed to connect: $e');
      _isConnected = false;
      _isConnectedController.add(false);
      _scheduleReconnect();
    }
  }

  /// Connect to Gemini Native Audio WebSocket for end-to-end speech-to-speech
  /// This uses gemini-2.5-flash-native-audio for high-quality voice conversations
  void connectGeminiVoice() {
    if (_voiceChannel != null) return; // Already connected

    try {
      debugPrint('Gemini Voice WebSocket: Connecting to $_geminiVoiceWsUrl');
      _voiceChannel = WebSocketChannel.connect(Uri.parse(_geminiVoiceWsUrl));

      _voiceChannel!.stream.listen(
        (message) {
          try {
            final data = jsonDecode(message) as Map<String, dynamic>;
            _handleGeminiVoiceMessage(data);
          } catch (e) {
            debugPrint('Gemini Voice WebSocket: Error parsing message: $e');
          }
        },
        onError: (error) {
          debugPrint('Gemini Voice WebSocket: Connection error: $error');
          _handleVoiceDisconnection();
        },
        onDone: () {
          debugPrint('Gemini Voice WebSocket: Connection closed');
          _handleVoiceDisconnection();
        },
      );
    } catch (e) {
      debugPrint('Gemini Voice WebSocket: Failed to connect: $e');
      _handleVoiceDisconnection();
    }
  }

  void _handleVoiceDisconnection() {
    _voiceChannel = null;
    debugPrint('Gemini Voice WebSocket: Disconnected state set');
  }

  void disconnectVoice() {
    _voiceChannel?.sink.close();
    _voiceChannel = null;
  }

  /// Handle messages from Gemini Native Audio WebSocket
  void _handleGeminiVoiceMessage(Map<String, dynamic> data) {
    final type = data['type'];

    switch (type) {
      case 'connected':
        debugPrint('Gemini Voice: Connected - Model: ${data['model']}');
        _isConnected = true;
        _reconnectAttempts = 0;
        _isConnectedController.add(true);
        _startPingTimer();
        _startKeepAliveTimer();
        break;

      case 'pong':
        // Server responded to ping
        break;

      case 'status':
        // Processing status: 'processing', 'generating', etc.
        data['source'] = 'voice';
        _messageController.add(data);
        break;

      case 'response':
        // Main response with text AND audio
        debugPrint(
          'Gemini Voice: Response received (latency: ${data['latency']}s)',
        );
        data['source'] = 'voice';
        _messageController.add(data);
        break;

      case 'speech':
        // TTS response (text was sent, audio returned)
        data['source'] = 'voice';
        _messageController.add(data);
        break;

      case 'error':
        debugPrint('Gemini Voice Error: ${data['message']}');
        data['source'] = 'voice';
        _messageController.add(data);
        break;

      case 'timeout_warning':
        debugPrint('Gemini Voice: ${data['message']}');
        data['source'] = 'voice';
        _messageController.add(data);
        break;

      default:
        debugPrint('Gemini Voice: Unknown message type: $type');
        data['source'] = 'voice';
        _messageController.add(data);
    }
  }

  void _handleIncomingMessage(Map<String, dynamic> data) {
    final type = data['type'];

    switch (type) {
      case 'connected':
        debugPrint('WebSocket: Connected - Session ID: ${data['session_id']}');
        _isConnected = true;
        _reconnectAttempts = 0;
        _isConnectedController.add(true);
        _startPingTimer();
        _startKeepAliveTimer();
        break;

      case 'ping':
        // Respond to server heartbeat
        _sendPong();
        break;

      case 'pong':
        // Server responded to our keep-alive ping - connection is healthy
        if (_lastPingSentAt != null) {
          final latency =
              DateTime.now().difference(_lastPingSentAt!).inMilliseconds;
          _connectionManager.updateLatency(latency);
          debugPrint(
              'WebSocket: Latency ${latency}ms (${_connectionManager.getConnectionQuality()})');
        }
        break;

      case 'chunk':
      case 'resume':
      case 'status':
      case 'error':
      case 'title_updated':
      case 'response_start':
      case 'tool_start':
      case 'done':
      case 'complete': // Signals response completion
      case 'end': // Signals response end
      case 'message': // Full message response
      case 'response': // Gemini Native Audio response with text and audio
      case 'speech': // TTS response
      case 'audio': // Audio response from server
      case 'reasoning_chunk': // Chain of thought reasoning chunks
      // Voice-specific message types
      case 'transcription': // User's speech transcribed to text
      case 'listening': // Status: listening for audio
      case 'transcribing': // Status: processing audio
        // Forward to message stream for UI handling
        data['source'] = 'main';
        _messageController.add(data);
        break;

      default:
        debugPrint('WebSocket: Unknown message type: $type');
        data['source'] = 'main';
        _messageController.add(data);
    }
  }

  void _sendPong() {
    if (_channel != null && _isConnected) {
      _lastPingSentAt = DateTime.now();
      _channel!.sink.add(jsonEncode({'type': 'pong'}));
    }
  }

  void _startPingTimer() {
    _pingTimer?.cancel();
    // Server sends ping every ~30s, but we'll check more frequently
    _pingTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      if (!_isConnected) {
        _pingTimer?.cancel();
      }
    });
  }

  void _startKeepAliveTimer() {
    _keepAliveTimer?.cancel();
    // Send keep-alive ping every 20 seconds to maintain connection
    _keepAliveTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (_isConnected && _channel != null) {
        try {
          _lastPingSentAt = DateTime.now();
          _channel!.sink.add(jsonEncode({'type': 'ping'}));
          debugPrint('WebSocket: Keep-alive ping sent');
        } catch (e) {
          debugPrint('WebSocket: Keep-alive ping failed: $e');
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
      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(Duration(seconds: backoffSeconds), connect);
    }
  }

  void _handleDisconnection() {
    _isConnected = false;
    _isConnectedController.add(false);
    _pingTimer?.cancel();
    _scheduleReconnect();
  }

  void resetConnection() {
    debugPrint('WebSocket: Resetting connection attempts');
    _reconnectAttempts = 0;
    _reconnectTimer?.cancel();
    _keepAliveTimer?.cancel();
    _pingTimer?.cancel();
    connect();
  }

  Future<void> ensureConnected() async {
    if (!_isConnected || _channel == null) {
      connect();
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }

  void sendMessage({
    required String message,
    required String userId, // Added userId to signature to match request
    String? threadId,
    String? modelPreference,
    String? fileUrl,
    String? fileType,
    String? audioData, // Kept to avoid breaking _stopRecording
    Map<String, dynamic>? extraData,
  }) {
    // 1. Match the Python Script's Payload Structure exactly
    final Map<String, dynamic> data = {
      "type": "message", // Required by new protocol
      "message": message, // Script uses "message", not "content"
      "user_id": userId,
      "thread_id": threadId ?? this.threadId,
      "model_preference":
          modelPreference ?? "auto", // Default to auto (let Agent decide)
      "timestamp": DateTime.now().millisecondsSinceEpoch,
      "metadata": {
        "is_voice_mode": false,
        if (studentName != null) "student_name": studentName,
        if (academicLevel != null) "academic_level": academicLevel,
        if (extraData?['metadata'] is Map) ...extraData?['metadata'],
      },
    };

    // 2. Add File URL (Critical for Vision)
    if (fileUrl != null) {
      data['file_url'] = fileUrl;
      if (fileType != null) data['file_type'] = fileType;
    }

    // 3. Handle Audio (Legacy/Parallel feature support)
    if (audioData != null) {
      data['audio_data'] = audioData; // or however backend expects it
    }

    if (extraData != null) {
      data.addAll(extraData);
    }

    // 4. Queue message if disconnected, otherwise send immediately
    if (_channel == null || !_isConnected) {
      debugPrint('WS Not connected - queueing message for retry');
      _queuedMessages.add(data);
      // Attempt to reconnect if not already trying
      if (!_isConnected && _reconnectAttempts < _maxReconnectAttempts) {
        connect();
      }
      return;
    }

    debugPrint('Sending Payload: ${jsonEncode(data)}');
    _channel!.sink.add(jsonEncode(data));
  }

  /// Send audio message for live voice mode (legacy endpoint)
  /// Audio should be base64-encoded m4a or wav format
  /// @deprecated Use sendGeminiAudioMessage for better quality
  void sendAudioMessage({
    required String base64Audio,
    required String userId,
    String? threadId,
    String? modelPreference,
  }) {
    if (_channel == null) {
      debugPrint('Voice WS Not connected');
      return;
    }

    final Map<String, dynamic> data = {
      "type": "audio",
      "user_id": userId,
      "audioData": base64Audio,
      "modelPreference": modelPreference ?? "fast", // Recommended for voice
      "thread_id": threadId ?? this.threadId,
    };

    debugPrint('Sending Voice Audio Payload (${base64Audio.length} bytes)');
    _channel!.sink.add(jsonEncode(data));
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
  }) {
    if (_voiceChannel == null) {
      debugPrint('Gemini Voice WS Not connected');
      return;
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
  void sendGeminiTextForSpeech({required String text, String voice = 'Aoede'}) {
    if (_voiceChannel == null) {
      debugPrint('Gemini Voice WS Not connected');
      return;
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

  void dispose() {
    _reconnectTimer?.cancel();
    _keepAliveTimer?.cancel();
    _pingTimer?.cancel();
    _channel?.sink.close();
    _voiceChannel?.sink.close();
    _messageController.close();
    _isConnectedController.close();
    WidgetsBinding.instance.removeObserver(this);
    _queuedMessages.clear();
    debugPrint('WebSocket: Service disposed and lifecycle observer removed');
  }
}
