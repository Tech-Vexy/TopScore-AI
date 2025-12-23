class ChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final String? audioUrl;
  final String? imageUrl;
  final int?
  feedback; // 1 for thumbs up, -1 for thumbs down, null for no feedback

  ChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.audioUrl,
    this.imageUrl,
    this.feedback,
  });
}
