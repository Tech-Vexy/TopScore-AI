import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:uuid/uuid.dart';
import 'package:universal_io/io.dart';
import 'package:http/http.dart' as http;

class WebSocketService {
  WebSocketChannel? _channel;
  final StreamController<Map<String, dynamic>> _messageController = StreamController.broadcast();
  final StreamController<bool> _isConnectedController = StreamController.broadcast();
  
  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;
  Stream<bool> get isConnectedStream => _isConnectedController.stream;
  
  final String userId;
  String threadId = const Uuid().v4();

  WebSocketService({required this.userId});

  String get _baseUrl {
    return 'https://tutoragent-qcaa.onrender.com';
  }

  String get _wsUrl {
    return 'wss://tutoragent-qcaa.onrender.com/ws/chat';
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
      print('Error fetching threads: $e');
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> fetchMessages(String threadId) async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/threads/$threadId/messages'));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.cast<Map<String, dynamic>>();
      }
    } catch (e) {
      print('Error fetching messages: $e');
    }
    return [];
  }

  void connect() {
    try {
      print('Connecting to $_wsUrl');
      _channel = WebSocketChannel.connect(Uri.parse(_wsUrl));
      _isConnectedController.add(true);
      _channel!.stream.listen(
        (message) {
          try {
            final data = jsonDecode(message);
            _messageController.add(data);
          } catch (e) {
            print('Error parsing message: $e');
          }
        },
        onError: (error) {
          print('WebSocket error: $error');
          _messageController.add({'type': 'error', 'content': 'Connection error'});
          _isConnectedController.add(false);
        },
        onDone: () {
          print('WebSocket closed');
          _messageController.add({'type': 'error', 'content': 'Connection closed'});
          _isConnectedController.add(false);
        },
      );
    } catch (e) {
      print('Connection exception: $e');
    }
  }

  void sendMessage({
    required String message,
    String? imageData,
    String? audioData,
    String modelPreference = 'smart',
  }) {
    if (_channel == null) return;

    final payload = {
      'user_id': userId,
      'thread_id': threadId,
      'message': message,
      'image_data': imageData,
      'audio_data': audioData,
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
