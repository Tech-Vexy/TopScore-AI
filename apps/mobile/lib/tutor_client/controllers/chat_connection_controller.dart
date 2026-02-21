import 'dart:async';
import 'package:flutter/foundation.dart';
import '../enhanced_websocket_service.dart';

// --- Event Classes ---
abstract class ChatEvent {}

class StatusEvent extends ChatEvent {
  final String status;
  StatusEvent(this.status);
}

class ResponseStartEvent extends ChatEvent {
  final String messageId;
  ResponseStartEvent(this.messageId);
}

class ContentChunkEvent extends ChatEvent {
  final String content;
  final String messageId;
  final bool isThinking;
  ContentChunkEvent(this.content, this.messageId, {this.isThinking = false});
}

class AudioEvent extends ChatEvent {
  final String url;
  final String? messageId;
  AudioEvent(this.url, {this.messageId});
}

class TranscriptionEvent extends ChatEvent {
  final String text;
  TranscriptionEvent(this.text);
}

class VideoEvent extends ChatEvent {
  final Map<String, dynamic> videoData;
  VideoEvent(this.videoData);
}

class ToolStartEvent extends ChatEvent {
  final String toolName;
  ToolStartEvent(this.toolName);
}

class StreamCompleteEvent extends ChatEvent {
  final String? messageId;
  final String? finalContent;
  StreamCompleteEvent({this.messageId, this.finalContent});
}

class SourcesEvent extends ChatEvent {
  final List<dynamic> sources;
  SourcesEvent(this.sources);
}

class SuggestionsEvent extends ChatEvent {
  final List<Map<String, String>> suggestions;
  SuggestionsEvent(this.suggestions);
}

// --- Controller ---
class ChatConnectionController extends ChangeNotifier {
  final EnhancedWebSocketService _wsService;
  StreamSubscription? _messageSub;
  StreamSubscription? _connectionSub;

  // Expose connection state
  bool get isConnected => _wsService.isConnected;
  String get threadId => _wsService.threadId;

  // Stream of typed events for the UI to consume
  final StreamController<ChatEvent> _eventController =
      StreamController.broadcast();
  Stream<ChatEvent> get eventStream => _eventController.stream;

  ChatConnectionController({required String userId})
      : _wsService = EnhancedWebSocketService(userId: userId);

  // Getter for underlying service (for AudioController compatibility)
  EnhancedWebSocketService get wsService => _wsService;

  void init() {
    _wsService.connect();

    _connectionSub = _wsService.isConnectedStream.listen((connected) {
      notifyListeners();
    });

    _messageSub = _wsService.messageStream.listen(_handleRawMessage);
  }

  void setThreadId(String id) {
    _wsService.setThreadId(id);
    notifyListeners();
  }

  void connect() => _wsService.connect();

  void sendMessage({
    required String message,
    required String userId,
    String? fileUrl,
    String? fileType,
    String? modelPreference,
  }) {
    _wsService.sendMessage(
      message: message,
      userId: userId,
      fileUrl: fileUrl,
      fileType: fileType,
      modelPreference: modelPreference,
    );
  }

  String? _currentMessageId;

  void _handleRawMessage(Map<String, dynamic> data) {
    final type = data['type'];
    // Try to get ID from data, otherwise use the current tracking ID
    final incomingId = data['id'] ?? data['message_id'];
    final messageId = incomingId ?? _currentMessageId;

    if (type == null) return;

    switch (type) {
      case 'status':
        if (data['status'] != null && !_eventController.isClosed) {
          _eventController.add(StatusEvent(data['status']));
        }
        break;

      case 'response_start':
        if (incomingId != null) {
          _currentMessageId = incomingId;
          if (!_eventController.isClosed) {
            _eventController.add(ResponseStartEvent(incomingId));
          }
        }
        break;

      case 'chunk':
      case 'text_chunk':
        final content = data['content'] ?? data['chunk'] ?? '';
        if (content.isNotEmpty &&
            messageId != null &&
            !_eventController.isClosed) {
          _eventController.add(ContentChunkEvent(content, messageId));
        }
        break;

      case 'reasoning_chunk':
        final content = data['content'] ?? data['chunk'] ?? '';
        if (content.isNotEmpty &&
            messageId != null &&
            !_eventController.isClosed) {
          _eventController
              .add(ContentChunkEvent(content, messageId, isThinking: true));
        }
        break;

      case 'audio':
        final url = data['url'] ?? data['audio_url'];
        if (url != null && !_eventController.isClosed) {
          _eventController.add(AudioEvent(url, messageId: messageId));
        }
        break;

      case 'transcription':
        final text = data['content'] ?? '';
        if (text.isNotEmpty && !_eventController.isClosed) {
          _eventController.add(TranscriptionEvent(text));
        }
        break;

      case 'tool_start':
        final tool = data['tool'] ?? 'unknown';
        if (!_eventController.isClosed) {
          _eventController.add(ToolStartEvent(tool));
        }
        break;

      case 'done':
      case 'complete':
      case 'end':
        final content = data['content'];
        if (!_eventController.isClosed) {
          _eventController.add(
              StreamCompleteEvent(messageId: messageId, finalContent: content));
        }
        break;
    }

    // Handle Metadata (Sources) which might come with other messages or separately
    if (data.containsKey('sources') && !_eventController.isClosed) {
      _eventController.add(SourcesEvent(data['sources']));
    }

    // Handle Suggestions
    if (data['type'] == 'suggestions' && data['suggestions'] != null) {
      final rawList = data['suggestions'] as List;
      final parsed = rawList.map((item) {
        final map = Map<String, dynamic>.from(item);
        return {
          'emoji': map['emoji']?.toString() ?? '✨',
          'title': map['title']?.toString() ?? '',
          'subtitle': map['subtitle']?.toString() ?? '',
        };
      }).toList();
      if (!_eventController.isClosed) {
        _eventController.add(SuggestionsEvent(parsed));
      }
    }
  }

  @override
  void dispose() {
    _messageSub?.cancel();
    _connectionSub?.cancel();
    _eventController.close();
    _wsService.dispose();
    super.dispose();
  }
}
