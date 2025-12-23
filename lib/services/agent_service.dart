import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;

/// A production-grade WebSocket service for chat communication with resumable sessions.
/// This service implements the standardized JSON schema for uniformity across platforms.
class AgentService {
  // Singleton instance
  static final AgentService _instance = AgentService._internal();

  factory AgentService() {
    return _instance;
  }

  AgentService._internal();

  WebSocketChannel? _channel;
  String? _sessionId;
  Timer? _pingTimer;

  // Update this URL to point to your actual backend
  // Use 'ws://10.0.2.2:8081/ws/chat' for Android Emulator
  // Use 'ws://localhost:8081/ws/chat' for web
  final String _baseUrl = "ws://10.0.2.2:8081/ws/chat";

  // Streams for UI to listen to
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;

  // Stream controller for connection status
  final _statusController = StreamController<bool>.broadcast();
  Stream<bool> get statusStream => _statusController.stream;

  // Stream controller for connection status
  final _statusController = StreamController<bool>.broadcast();
  Stream<bool> get statusStream => _statusController.stream;

  /// Initializes session and connects
  Future<void> connect() async {
    await _loadSessionId();
    _connectSocket();
  }

  Future<void> _loadSessionId() async {
    final prefs = await SharedPreferences.getInstance();
    _sessionId = prefs.getString('topscore_session_id');
    if (_sessionId == null) {
      _sessionId = const Uuid().v4();
      await prefs.setString('topscore_session_id', _sessionId!);
    }
    print("Session ID: $_sessionId");
  }

  void _connectSocket() {
    if (_sessionId == null) return;

    try {
      print("Connecting to: $_baseUrl/$_sessionId");
      _channel = WebSocketChannel.connect(Uri.parse('$_baseUrl/$_sessionId'));
      _statusController.add(true);

      _channel!.stream.listen(
        (message) {
          final data = jsonDecode(message);
          _messageController.add(data);
        },
        onDone: () {
          print("Disconnected");
          _statusController.add(false);
          _reconnect();
        },
        onError: (error) {
          print("WS Error: $error");
          _statusController.add(false);
          _reconnect();
        },
      );
      
      _startPing();
    } catch (e) {
      print("Connection failed: $e");
      _statusController.add(false);
      _reconnect();
    }
  }

  void _reconnect() {
    _pingTimer?.cancel();
    _channel = null;
    // Simple exponential backoff could go here
    Future.delayed(const Duration(seconds: 3), () {
      if (_sessionId != null) {
        _connectSocket();
      }
    });
  }

  void _startPing() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 25), (timer) {
      if (_channel != null) {
        try {
          // Send a ping to keep TCP alive (server ignores this)
          _channel!.sink.add(jsonEncode({"type": "ping"}));
        } catch (e) {
          print("Ping failed: $e");
        }
      }
    });
  }

  void sendMessage(String text, {String? imageBase64, String? fileUrl}) {
    if (_channel == null) return;

    final payload = {
      "user_id": "mobile_user", // You can store real user ID similarly
      "thread_id": "thread_1",
      "message": text,
      "stream": true,
      "model_preference": "smart" // or 'fast'
    };

    if (imageBase64 != null) {
      payload["image_data"] = imageBase64; // "data:image/png;base64,..."
    }

    if (fileUrl != null) {
      payload["file_url"] = fileUrl;
    }
    
    try {
      _channel!.sink.add(jsonEncode(payload));
    } catch (e) {
      print("Error sending message: $e");
    }
  }

  void dispose() {
    _pingTimer?.cancel();
    _channel?.sink.close(status.goingAway);
    _messageController.close();
    _statusController.close();
  }
}
