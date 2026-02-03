class Quiz {
  final String id;
  final String title;
  final String? description;
  final String? topic;
  final String? difficulty;
  final List<QuizQuestion> questions;
  final DateTime createdAt;
  final String? createdBy;

  Quiz({
    required this.id,
    required this.title,
    this.description,
    this.topic,
    this.difficulty,
    required this.questions,
    required this.createdAt,
    this.createdBy,
  });

  factory Quiz.fromJson(Map<String, dynamic> json) {
    return Quiz(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'],
      topic: json['topic'],
      difficulty: json['difficulty'],
      questions: (json['questions'] as List?)
              ?.map((q) => QuizQuestion.fromJson(q))
              .toList() ??
          [],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      createdBy: json['createdBy'],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'topic': topic,
        'difficulty': difficulty,
        'questions': questions.map((q) => q.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'createdBy': createdBy,
      };
}

class QuizQuestion {
  final String id;
  final String question;
  final String? questionText;
  final List<String> options;
  final String correctAnswer;
  final int? correctIndex;
  final String? explanation;

  QuizQuestion({
    required this.id,
    required this.question,
    String? questionText,
    required this.options,
    required this.correctAnswer,
    int? correctIndex,
    this.explanation,
  })  : questionText = questionText ?? question,
        correctIndex = correctIndex ?? options.indexOf(correctAnswer);

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    final options = List<String>.from(json['options'] ?? []);
    final correctAnswer = json['correctAnswer'] ?? '';
    return QuizQuestion(
      id: json['id'] ?? '',
      question: json['question'] ?? '',
      questionText: json['questionText'],
      options: options,
      correctAnswer: correctAnswer,
      correctIndex: json['correctIndex'] ?? options.indexOf(correctAnswer),
      explanation: json['explanation'],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'question': question,
        'questionText': questionText,
        'options': options,
        'correctAnswer': correctAnswer,
        'correctIndex': correctIndex,
        'explanation': explanation,
      };
}
