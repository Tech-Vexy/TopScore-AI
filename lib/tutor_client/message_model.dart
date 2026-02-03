import '../models/video_result.dart';

class ChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final String? audioUrl;
  final String? imageUrl;
  final int?
      feedback; // 1 for thumbs up, -1 for thumbs down, null for no feedback
  final bool isBookmarked;
  final bool isTemporary;
  final bool isComplete;
  final String? reasoning;
  final List<SourceMetadata>? sources;
  final Map<String, dynamic>? quizData;
  final List<String>? mathSteps;
  final String? mathAnswer;
  final List<VideoResult>? videos;

  ChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.audioUrl,
    this.imageUrl,
    this.feedback,
    this.isBookmarked = false,
    this.isTemporary = false,
    this.isComplete = true,
    this.reasoning,
    this.sources,
    this.quizData,
    this.mathSteps,
    this.mathAnswer,
    this.videos,
  });

  ChatMessage copyWith({
    String? id,
    String? text,
    bool? isUser,
    DateTime? timestamp,
    String? audioUrl,
    String? imageUrl,
    int? feedback,
    bool? isBookmarked,
    bool? isTemporary,
    bool? isComplete,
    String? reasoning,
    List<SourceMetadata>? sources,
    Map<String, dynamic>? quizData,
    List<String>? mathSteps,
    String? mathAnswer,
    List<VideoResult>? videos,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      text: text ?? this.text,
      isUser: isUser ?? this.isUser,
      timestamp: timestamp ?? this.timestamp,
      audioUrl: audioUrl ?? this.audioUrl,
      imageUrl: imageUrl ?? this.imageUrl,
      feedback: feedback ?? this.feedback,
      isBookmarked: isBookmarked ?? this.isBookmarked,
      isTemporary: isTemporary ?? this.isTemporary,
      isComplete: isComplete ?? this.isComplete,
      reasoning: reasoning ?? this.reasoning,
      sources: sources ?? this.sources,
      quizData: quizData ?? this.quizData,
      mathSteps: mathSteps ?? this.mathSteps,
      mathAnswer: mathAnswer ?? this.mathAnswer,
      videos: videos ?? this.videos,
    );
  }
}

class SourceMetadata {
  final String title;
  final String url;
  final String? source;
  final int? score;
  final String? type;
  final String? author;

  SourceMetadata({
    required this.title,
    required this.url,
    this.source,
    this.score,
    this.type,
    this.author,
  });

  factory SourceMetadata.fromJson(Map<String, dynamic> json) {
    return SourceMetadata(
      title: json['title'] ?? '',
      url: json['url'] ?? '',
      source: json['source'],
      score: json['score'],
      type: json['type'],
      author: json['author'],
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'url': url,
        'source': source,
        'score': score,
        'type': type,
        'author': author,
      };
}
