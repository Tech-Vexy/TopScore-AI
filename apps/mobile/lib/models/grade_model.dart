class GradeModel {
  final String subject;
  final int percentage;
  final String grade;
  final String term;

  GradeModel({
    required this.subject,
    required this.percentage,
    required this.grade,
    required this.term,
  });

  Map<String, dynamic> toJson() => {
    'subject': subject,
    'percentage': percentage,
    'grade': grade,
    'term': term,
  };

  factory GradeModel.fromJson(Map<String, dynamic> json) {
    return GradeModel(
      subject: json['subject'] ?? '',
      percentage: json['percentage'] ?? 0,
      grade: json['grade'] ?? 'E',
      term: json['term'] ?? '',
    );
  }
}
