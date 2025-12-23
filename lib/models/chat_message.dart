enum MessageSender { user, ai }

class ChatMessage {
  final String id;
  final MessageSender sender;
  String content;
  bool isThinking;
  final String? imageUrl;

  ChatMessage({
    required this.id,
    required this.sender,
    required this.content,
    this.isThinking = false,
    this.imageUrl,
  });
}
