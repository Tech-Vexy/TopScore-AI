import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:uuid/uuid.dart';
import 'package:http/http.dart' as http;

class WebSocketService {
  WebSocketChannel? _channel;
  final StreamController<Map<String, dynamic>> _messageController =
      StreamController.broadcast();
  final StreamController<bool> _isConnectedController =
      StreamController.broadcast();

  bool _isConnected = false; // Track connection state

  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;
  Stream<bool> get isConnectedStream => _isConnectedController.stream;
  bool get isConnected => _isConnected; // Expose connection state

  final String userId;
  String threadId = const Uuid().v4();

  WebSocketService({required this.userId});

  String get _baseUrl {
    return 'http://127.0.0.1:8081';
  }

  String get _wsUrl {
    return 'ws://127.0.0.1:8081/ws/chat';
  }

  void setThreadId(String newThreadId) {
    threadId = newThreadId;
  }

  Future<List<Map<String, dynamic>>> fetchThreads() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/threads/$userId'));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      // Error fetching threads
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> fetchMessages(String threadId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/threads/$threadId/messages_direct'),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      // Error fetching messages
    }
    return [];
  }

  Future<bool> deleteThread(String threadId) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/threads/$threadId'),
      );
      if (response.statusCode == 200) {
        return true;
      }
    } catch (e) {
      // Error deleting thread
    }
    return false;
  }

  Future<bool> editMessage({
    required String threadId,
    required String messageId,
    required String newContent,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/threads/$threadId/messages/$messageId'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'content': newContent}),
      );
      if (response.statusCode == 200) {
        return true;
      }
    } catch (e) {
      // Error editing message
    }
    return false;
  }

  Future<bool> regenerateResponse({
    required String threadId,
    String modelPreference = 'smart',
  }) async {
    await ensureConnected();

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/threads/$threadId/regenerate'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'model_preference': modelPreference,
          'user_id': userId,
        }),
      );
      if (response.statusCode == 200) {
        return true;
      }
    } catch (e) {
      // Error regenerating response
    }
    return false;
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
    try {
      _channel = WebSocketChannel.connect(Uri.parse(_wsUrl));
      _isConnected = true;
      _isConnectedController.add(true);

      _channel!.stream.listen(
        (message) {
          try {
            final data = jsonDecode(message);
            _messageController.add(data);
          } catch (e) {
            // Error parsing message
          }
        },
        onError: (error) {
          _isConnected = false;
          _messageController.add({
            'type': 'error',
            'content': 'Connection error',
          });
          _isConnectedController.add(false);
        },
        onDone: () {
          _isConnected = false;
          _messageController.add({
            'type': 'error',
            'content': 'Sorry, Seems the AI Tutor offline',
          });
          _isConnectedController.add(false);
        },
      );
    } catch (e) {
      _isConnected = false;
    }
  }

  Future<void> ensureConnected() async {
    if (!_isConnected || _channel == null) {
      connect();
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }

  void sendMessage({
    required String message,
    String? imageData,
    String? audioData,
    String? extractedText,
    String modelPreference = 'smart',
  }) {
    if (_channel == null) return;

    final payload = {
      'user_id': userId,
      'thread_id': threadId,
      'text': message,
      'image': imageData,
      'audio': audioData,
      'extracted_text': extractedText,
      'model_preference': modelPreference,
    };

    _channel!.sink.add(jsonEncode(payload));
  }

  void dispose() {
    _channel?.sink.close();
    _messageController.close();
    _isConnectedController.close();
  }
}
