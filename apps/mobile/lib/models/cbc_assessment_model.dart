/// CBC Rubric levels as defined by KICD
/// EE = Exceeding Expectations, ME = Meeting Expectations,
/// AE = Approaching Expectations, BE = Below Expectations
enum CbcRubricLevel {
  ee('EE', 'Exceeding Expectations'),
  me('ME', 'Meeting Expectations'),
  ae('AE', 'Approaching Expectations'),
  be('BE', 'Below Expectations');

  final String code;
  final String label;
  const CbcRubricLevel(this.code, this.label);

  static CbcRubricLevel fromCode(String code) {
    return CbcRubricLevel.values.firstWhere(
      (e) => e.code == code.toUpperCase(),
      orElse: () => CbcRubricLevel.ae,
    );
  }
}

/// Assessment types used in CBC formative and summative assessment
enum CbcAssessmentType {
  formative,
  summative,
  portfolio,
  project,
  peerAssessment,
  selfAssessment,
  observation,
}

/// The seven CBC core competencies tracked across all learning areas
class CbcCompetency {
  static const String communication = 'Communication and Collaboration';
  static const String criticalThinking = 'Critical Thinking and Problem Solving';
  static const String creativity = 'Creativity and Imagination';
  static const String citizenship = 'Citizenship';
  static const String digitalLiteracy = 'Digital Literacy';
  static const String learningToLearn = 'Learning to Learn';
  static const String selfEfficacy = 'Self-Efficacy';

  static const List<String> all = [
    communication,
    criticalThinking,
    creativity,
    citizenship,
    digitalLiteracy,
    learningToLearn,
    selfEfficacy,
  ];
}

/// Represents a single CBC assessment record aligned to KICD standards
class CbcAssessmentModel {
  final String? id;
  final String learningArea; // e.g., "Mathematics", "Integrated Science"
  final String? strand; // e.g., "Numbers", "Measurement"
  final String? subStrand; // e.g., "Whole Numbers", "Length"
  final CbcRubricLevel rubricLevel;
  final String term; // e.g., "Term 1", "Term 2", "Term 3"
  final CbcAssessmentType assessmentType;
  final String? teacherRemarks;
  final DateTime assessedAt;
  final Map<String, String>? competencyRatings; // competency name -> rubric code
  final int? grade; // Grade 1-12

  CbcAssessmentModel({
    this.id,
    required this.learningArea,
    this.strand,
    this.subStrand,
    required this.rubricLevel,
    required this.term,
    required this.assessmentType,
    this.teacherRemarks,
    required this.assessedAt,
    this.competencyRatings,
    this.grade,
  });

  factory CbcAssessmentModel.fromJson(Map<String, dynamic> json) {
    return CbcAssessmentModel(
      id: json['id'],
      learningArea: json['learning_area'] ?? '',
      strand: json['strand'],
      subStrand: json['sub_strand'],
      rubricLevel: CbcRubricLevel.fromCode(json['rubric_level'] ?? 'AE'),
      term: json['term'] ?? '',
      assessmentType: CbcAssessmentType.values.firstWhere(
        (e) => e.name == json['assessment_type'],
        orElse: () => CbcAssessmentType.formative,
      ),
      teacherRemarks: json['teacher_remarks'],
      assessedAt: json['assessed_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['assessed_at'])
          : DateTime.now(),
      competencyRatings: json['competency_ratings'] != null
          ? Map<String, String>.from(json['competency_ratings'])
          : null,
      grade: json['grade'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'learning_area': learningArea,
      if (strand != null) 'strand': strand,
      if (subStrand != null) 'sub_strand': subStrand,
      'rubric_level': rubricLevel.code,
      'term': term,
      'assessment_type': assessmentType.name,
      if (teacherRemarks != null) 'teacher_remarks': teacherRemarks,
      'assessed_at': assessedAt.millisecondsSinceEpoch,
      if (competencyRatings != null) 'competency_ratings': competencyRatings,
      if (grade != null) 'grade': grade,
    };
  }
}

/// CBC Learning Areas organized by education level per KICD guidelines
class CbcLearningAreas {
  /// Lower Primary (Grade 1-3)
  static const List<String> lowerPrimary = [
    'Literacy Activities (English)',
    'Literacy Activities (Kiswahili)',
    'Mathematical Activities',
    'Environmental Activities',
    'Hygiene and Nutrition Activities',
    'Religious Education',
    'Movement and Creative Activities',
  ];

  /// Upper Primary (Grade 4-6)
  static const List<String> upperPrimary = [
    'English',
    'Kiswahili',
    'Mathematics',
    'Science and Technology',
    'Social Studies',
    'Religious Education',
    'Creative Arts',
    'Physical and Health Education',
    'Home Science',
    'Agriculture',
  ];

  /// Junior Secondary (Grade 7-9)
  static const List<String> juniorSecondary = [
    'English',
    'Kiswahili',
    'Mathematics',
    'Integrated Science',
    'Health Education',
    'Pre-Technical and Pre-Career Education',
    'Social Studies',
    'Religious Education',
    'Business Studies',
    'Agriculture',
    'Life Skills Education',
    'Sports and Physical Education',
    'Computer Science',
  ];

  /// Senior Secondary (Grade 10-12) - common core
  static const List<String> seniorSecondaryCore = [
    'English',
    'Kiswahili',
    'Mathematics',
  ];

  /// 8-4-4 / KCSE subjects (Form 1-4)
  static const List<String> kcseSubjects = [
    'Mathematics',
    'English',
    'Kiswahili',
    'Chemistry',
    'Biology',
    'Physics',
    'History',
    'Geography',
    'CRE',
    'Business Studies',
    'Computer Studies',
    'Agriculture',
  ];

  /// Returns the appropriate learning areas/subjects for a given curriculum and grade
  static List<String> forGrade(String? curriculum, int? grade) {
    if (curriculum == null || grade == null) return kcseSubjects;

    final cur = curriculum.toUpperCase().trim();
    if (cur == '8-4-4' || cur == 'KCSE' || cur == '844') {
      return kcseSubjects;
    }

    // CBC
    if (grade <= 3) return lowerPrimary;
    if (grade <= 6) return upperPrimary;
    if (grade <= 9) return juniorSecondary;
    return seniorSecondaryCore;
  }
}
