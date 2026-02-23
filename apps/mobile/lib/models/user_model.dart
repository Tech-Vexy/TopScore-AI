import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final String? photoURL;
  final String role; // 'student', 'teacher', 'parent'
  final int? grade;
  final String schoolName;
  final String? educationLevel;
  final List<String>? subjects;
  final bool isSubscribed;
  final DateTime? subscriptionExpiry;
  final String? preferredLanguage;
  final int xp;
  final int level;
  final List<String> badges;
  final List<String>? interests;
  final String? careerMode;
  final String? phoneNumber;
  final String? curriculum;
  final bool parentalConsentGiven;
  final DateTime? dateOfBirth;
  final Map<String, double>? competencyScores; // CBC seven core competencies

  UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    this.photoURL,
    required this.role,
    this.grade,
    required this.schoolName,
    this.educationLevel,
    this.subjects,
    this.isSubscribed = false,
    this.subscriptionExpiry,
    this.preferredLanguage,
    this.xp = 0,
    this.level = 1,
    this.badges = const [],
    this.interests,
    this.careerMode,
    this.phoneNumber,
    this.curriculum,
    this.parentalConsentGiven = false,
    this.dateOfBirth,
    this.competencyScores,
  });

  /// Whether this user is under 18 based on dateOfBirth (Kenya DPA 2019 Section 33)
  bool get isMinor {
    if (dateOfBirth == null) return true; // Assume minor if unknown
    final now = DateTime.now();
    final age = now.year -
        dateOfBirth!.year -
        ((now.month < dateOfBirth!.month ||
                (now.month == dateOfBirth!.month && now.day < dateOfBirth!.day))
            ? 1
            : 0);
    return age < 18;
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'photoURL': photoURL,
      'role': role,
      'grade': grade,
      'schoolName': schoolName,
      'educationLevel': educationLevel,
      'subjects': subjects,
      'isSubscribed': isSubscribed,
      'subscriptionExpiry': subscriptionExpiry?.millisecondsSinceEpoch,
      'preferred_language': preferredLanguage,
      'xp': xp,
      'level': level,
      'badges': badges,
      'interests': interests,
      'careerMode': careerMode,
      'phoneNumber': phoneNumber,
      'curriculum': curriculum,
      'parental_consent_given': parentalConsentGiven,
      'date_of_birth': dateOfBirth?.millisecondsSinceEpoch,
      'competency_scores': competencyScores,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map, String uid) {
    DateTime? getDateTime(dynamic val) {
      if (val == null) {
        return null;
      }
      if (val is Timestamp) {
        return val.toDate();
      }
      if (val is int) {
        return DateTime.fromMillisecondsSinceEpoch(val);
      }
      return null;
    }

    return UserModel(
      uid: uid,
      email: map['email'] ?? '',
      displayName: map['displayName'] ?? '',
      photoURL: map['photoURL'] ?? map['photoUrl'],
      role: map['role'] ?? '',
      grade: map['grade'] is int
          ? map['grade']
          : int.tryParse(
              map['grade'].toString().replaceAll(RegExp(r'[^0-9]'), ''),
            ),
      schoolName: map['schoolName'] ?? '',
      educationLevel: map['educationLevel'],
      subjects:
          map['subjects'] != null ? List<String>.from(map['subjects']) : null,
      isSubscribed: map['isSubscribed'] ?? false,
      subscriptionExpiry: getDateTime(map['subscriptionExpiry']),
      preferredLanguage: map['preferred_language'],
      xp: map['xp'] ?? 0,
      level: map['level'] ?? 1,
      badges: map['badges'] != null ? List<String>.from(map['badges']) : [],
      interests:
          map['interests'] != null ? List<String>.from(map['interests']) : null,
      careerMode: map['careerMode'],
      phoneNumber: map['phoneNumber'],
      curriculum: map['curriculum'],
      parentalConsentGiven: map['parental_consent_given'] ?? false,
      dateOfBirth: getDateTime(map['date_of_birth']),
      competencyScores: map['competency_scores'] != null
          ? Map<String, double>.from(
              (map['competency_scores'] as Map).map(
                (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
              ),
            )
          : null,
    );
  }

  UserModel copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? photoURL,
    String? role,
    int? grade,
    String? schoolName,
    String? educationLevel,
    List<String>? subjects,
    bool? isSubscribed,
    DateTime? subscriptionExpiry,
    String? preferredLanguage,
    int? xp,
    int? level,
    List<String>? badges,
    List<String>? interests,
    String? careerMode,
    String? phoneNumber,
    String? curriculum,
    bool? parentalConsentGiven,
    DateTime? dateOfBirth,
    Map<String, double>? competencyScores,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoURL: photoURL ?? this.photoURL,
      role: role ?? this.role,
      grade: grade ?? this.grade,
      schoolName: schoolName ?? this.schoolName,
      educationLevel: educationLevel ?? this.educationLevel,
      subjects: subjects ?? this.subjects,
      isSubscribed: isSubscribed ?? this.isSubscribed,
      subscriptionExpiry: subscriptionExpiry ?? this.subscriptionExpiry,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      xp: xp ?? this.xp,
      level: level ?? this.level,
      badges: badges ?? this.badges,
      interests: interests ?? this.interests,
      careerMode: careerMode ?? this.careerMode,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      curriculum: curriculum ?? this.curriculum,
      parentalConsentGiven: parentalConsentGiven ?? this.parentalConsentGiven,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      competencyScores: competencyScores ?? this.competencyScores,
    );
  }

  String get gradeLabel {
    if (grade == null) {
      return 'General';
    }
    final cur = (educationLevel ?? curriculum)?.toUpperCase() ?? '';
    if (cur == 'KCSE' || cur == '8-4-4' || cur == '8.4.4' || cur == '844') {
      return 'Form $grade';
    }
    return 'Grade $grade';
  }
}
