import '../models/video_result.dart';

// Simple model for a single source citation
class SourceMetadata {
  final String title;
  final String? url;
  final String? author;
  final String type; // 'url', 'book', 'paper'

  SourceMetadata({
    required this.title,
    this.url,
    this.author,
    this.type = 'url',
  });

  factory SourceMetadata.fromJson(Map<String, dynamic> json) {
    return SourceMetadata(
      title: json['title'] ?? 'Unknown Source',
      url: json['url'],
      author: json['author'],
      type: json['type'] ?? 'url',
    );
  }
}

class ChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final String? audioUrl;
  final String? imageUrl;
  final int?
  feedback; // 1 for thumbs up, -1 for thumbs down, null for no feedback
  final List<SourceMetadata>? sources; // Sources for verification
  final String? reasoning; // Chain-of-thought reasoning
  final Map<String, dynamic>? quizData;
  final List<String>? mathSteps;
  final String? mathAnswer;
  final bool isBookmarked;
  final List<VideoResult>? videos; // <--- NEW: Video Results
  
  // Hybrid Streaming Architecture flags
  final bool isTemporary; // true when from WebSocket (temporary), false when from Firebase (final)
  final bool isComplete; // true when streaming is done

  ChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.audioUrl,
    this.imageUrl,
    this.feedback,
    this.sources,
    this.reasoning,
    this.quizData,
    this.mathSteps,
    this.mathAnswer,
    this.isBookmarked = false,
    this.videos,
    this.isTemporary = false, // Default: final Firebase message
    this.isComplete = true,   // Default: complete message
  });

  ChatMessage copyWith({
    String? id,
    String? text,
    bool? isUser,
    DateTime? timestamp,
    String? audioUrl,
    String? imageUrl,
    int? feedback,
    List<SourceMetadata>? sources,
    String? reasoning,
    Map<String, dynamic>? quizData,
    List<String>? mathSteps,
    String? mathAnswer,
    bool? isBookmarked,
    List<VideoResult>? videos,
    bool? isTemporary,
    bool? isComplete,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      text: text ?? this.text,
      isUser: isUser ?? this.isUser,
      timestamp: timestamp ?? this.timestamp,
      audioUrl: audioUrl ?? this.audioUrl,
      imageUrl: imageUrl ?? this.imageUrl,
      feedback: feedback ?? this.feedback,
      sources: sources ?? this.sources,
      reasoning: reasoning ?? this.reasoning,
      quizData: quizData ?? this.quizData,
      mathSteps: mathSteps ?? this.mathSteps,
      mathAnswer: mathAnswer ?? this.mathAnswer,
      isBookmarked: isBookmarked ?? this.isBookmarked,
      videos: videos ?? this.videos,
      isTemporary: isTemporary ?? this.isTemporary,
      isComplete: isComplete ?? this.isComplete,
    );
  }
}
