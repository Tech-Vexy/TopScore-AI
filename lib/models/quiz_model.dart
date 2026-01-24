/// Model representing a single quiz question
class QuizQuestion {
  final String questionText;
  final List<String> options;
  final int correctIndex;
  final String explanation;

  QuizQuestion({
    required this.questionText,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    return QuizQuestion(
      questionText: json['question_text'] ?? '',
      options: List<String>.from(json['options'] ?? []),
      correctIndex: json['correct_index'] ?? 0,
      explanation: json['explanation'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'question_text': questionText,
      'options': options,
      'correct_index': correctIndex,
      'explanation': explanation,
    };
  }
}

/// Model representing a complete quiz with multiple questions
class Quiz {
  final String title;
  final String topic;
  final String difficulty;
  final List<QuizQuestion> questions;

  Quiz({
    required this.title,
    required this.topic,
    required this.difficulty,
    required this.questions,
  });

  factory Quiz.fromJson(Map<String, dynamic> json) {
    return Quiz(
      title: json['title'] ?? 'Quiz',
      topic: json['topic'] ?? '',
      difficulty: json['difficulty'] ?? 'Medium',
      questions: (json['questions'] as List<dynamic>?)
              ?.map((item) => QuizQuestion.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'topic': topic,
      'difficulty': difficulty,
      'questions': questions.map((q) => q.toJson()).toList(),
    };
  }

  /// Returns the total number of questions
  int get questionCount => questions.length;
}
