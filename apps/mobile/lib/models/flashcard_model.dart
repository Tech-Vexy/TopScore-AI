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

  // CBC curriculum alignment fields
  final String? curriculum; // 'CBC' or '8-4-4'
  final String? learningArea; // CBC learning area or 8-4-4 subject
  final String? strand; // CBC strand (e.g., "Numbers")
  final String? subStrand; // CBC sub-strand (e.g., "Whole Numbers")
  final int? grade;

  FlashcardSet({
    required this.title,
    required this.topic,
    required this.cards,
    this.curriculum,
    this.learningArea,
    this.strand,
    this.subStrand,
    this.grade,
  });

  factory FlashcardSet.fromJson(Map<String, dynamic> json) {
    return FlashcardSet(
      title: json['title'] ?? 'Flashcards',
      topic: json['topic'] ?? '',
      cards: (json['cards'] as List<dynamic>?)
              ?.map((item) => Flashcard.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      curriculum: json['curriculum'],
      learningArea: json['learning_area'],
      strand: json['strand'],
      subStrand: json['sub_strand'],
      grade: json['grade'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'topic': topic,
      'cards': cards.map((c) => c.toJson()).toList(),
      if (curriculum != null) 'curriculum': curriculum,
      if (learningArea != null) 'learning_area': learningArea,
      if (strand != null) 'strand': strand,
      if (subStrand != null) 'sub_strand': subStrand,
      if (grade != null) 'grade': grade,
    };
  }
}
