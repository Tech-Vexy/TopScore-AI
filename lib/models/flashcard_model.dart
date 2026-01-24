/// Represents a single flashcard with a question/term and answer/definition
class Flashcard {
  final String front;
  final String back;
  final String? explanation;

  Flashcard({
    required this.front,
    required this.back,
    this.explanation,
  });

  factory Flashcard.fromJson(Map<String, dynamic> json) {
    return Flashcard(
      front: json['front'] ?? '',
      back: json['back'] ?? '',
      explanation: json['explanation'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'front': front,
      'back': back,
      if (explanation != null) 'explanation': explanation,
    };
  }
}

/// Represents a set of flashcards for a specific topic
class FlashcardSet {
  final String title;
  final String topic;
  final List<Flashcard> cards;

  FlashcardSet({
    required this.title,
    required this.topic,
    required this.cards,
  });

  factory FlashcardSet.fromJson(Map<String, dynamic> json) {
    return FlashcardSet(
      title: json['title'] ?? 'Flashcards',
      topic: json['topic'] ?? '',
      cards: (json['cards'] as List<dynamic>?)
              ?.map((item) => Flashcard.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'topic': topic,
      'cards': cards.map((c) => c.toJson()).toList(),
    };
  }
}
