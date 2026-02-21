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

  // CBC curriculum alignment fields
  final String? curriculum; // 'CBC' or '8-4-4'
  final String? learningArea; // CBC learning area or 8-4-4 subject
  final String? strand; // CBC strand (e.g., "Numbers")
  final String? subStrand; // CBC sub-strand (e.g., "Whole Numbers")
  final int? grade;

  Quiz({
    required this.title,
    required this.topic,
    required this.difficulty,
    required this.questions,
    this.curriculum,
    this.learningArea,
    this.strand,
    this.subStrand,
    this.grade,
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
      'difficulty': difficulty,
      'questions': questions.map((q) => q.toJson()).toList(),
      if (curriculum != null) 'curriculum': curriculum,
      if (learningArea != null) 'learning_area': learningArea,
      if (strand != null) 'strand': strand,
      if (subStrand != null) 'sub_strand': subStrand,
      if (grade != null) 'grade': grade,
    };
  }

  /// Returns the total number of questions
  int get questionCount => questions.length;
}
