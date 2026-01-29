import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class WebSocketService {
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

  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;
  Stream<bool> get isConnectedStream => _isConnectedController.stream;
  bool get isConnected => _isConnected;

  final String userId;
  String sessionId = const Uuid().v4(); // Session ID for WebSocket path
  String threadId = const Uuid().v4(); // Thread ID for chat history

  WebSocketService({required this.userId});

  // Configure these based on your deployment
  String get _baseUrl {
    return 'https://agent.topscoreapp.ai';
  }

  String get _wsUrl {
    // NEW: Session ID is now required in the path
    return 'wss://agent.topscoreapp.ai/ws/chat/$sessionId';
  }

  String get _voiceWsUrl {
    // Legacy voice endpoint for STT -> LLM -> TTS pipeline
    return 'wss://agent.topscoreapp.ai/voice/ws/live/$sessionId';
  }

  /// NEW: Gemini Native Audio WebSocket endpoint
  /// Uses gemini-2.5-flash-native-audio for end-to-end speech-to-speech
  String get _geminiVoiceWsUrl {
    return 'wss://agent.topscoreapp.ai/voice/ws/gemini/$sessionId';
  }

  void setThreadId(String newThreadId) {
    threadId = newThreadId;
  }

  void setSessionId(String newSessionId) {
    sessionId = newSessionId;
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
      debugPrint(
        'WebSocket: Connecting to $_wsUrl (attempt ${_reconnectAttempts + 1}/$_maxReconnectAttempts)',
      );
      _channel = WebSocketChannel.connect(Uri.parse(_wsUrl));

      _channel!.stream.listen(
        (message) {
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
        _messageController.add(data);
        break;

      case 'response':
        // Main response with text AND audio
        // data['text'] - Text transcription/response
        // data['audio'] - Base64 encoded audio response
        // data['audio_mime_type'] - MIME type of the audio
        // data['latency'] - Processing time in seconds
        debugPrint(
          'Gemini Voice: Response received (latency: ${data['latency']}s)',
        );
        _messageController.add(data);
        break;

      case 'speech':
        // TTS response (text was sent, audio returned)
        _messageController.add(data);
        break;

      case 'error':
        debugPrint('Gemini Voice Error: ${data['message']}');
        _messageController.add(data);
        break;

      case 'timeout_warning':
        debugPrint('Gemini Voice: ${data['message']}');
        _messageController.add(data);
        break;

      default:
        debugPrint('Gemini Voice: Unknown message type: $type');
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

      case 'chunk':
      case 'resume':
      case 'status':
      case 'error':
      case 'title_updated':
      // NEW: Handle these explicitly to identify them in logs or logic if needed
      case 'response_start':
      case 'tool_start':
      case 'done':
      // Voice-specific message types
      case 'transcription': // User's speech transcribed to text
      case 'listening': // Status: listening for audio
      case 'transcribing': // Status: processing audio
        // Forward to message stream for UI handling
        _messageController.add(data);
        break;

      default:
        debugPrint('WebSocket: Unknown message type: $type');
        _messageController.add(data);
    }
  }

  void _sendPong() {
    if (_channel != null && _isConnected) {
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
    if (_channel == null) {
      debugPrint('WS Not connected');
      return;
    }

    // 1. Match the Python Script's Payload Structure exactly
    final Map<String, dynamic> data = {
      "type": "message", // Required by new protocol
      "message": message, // Script uses "message", not "content"
      "user_id": userId,
      "thread_id": threadId ?? this.threadId,
      "model_preference": modelPreference ?? "smart", // Default to smart
      "timestamp": DateTime.now().millisecondsSinceEpoch,
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
  }
}
