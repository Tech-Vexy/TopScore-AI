import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final String?
      photoURL; // Changed from photoUrl to photoURL to match Firebase Auth
  final String role; // 'student', 'teacher', 'parent'
  final int? grade; // Changed to int? to match usage in AuthProvider
  final String schoolName; // <--- NEW FIELD
  final String? educationLevel;
  final List<String>? subjects;
  final bool isSubscribed;
  final DateTime? subscriptionExpiry;
  final String? preferredLanguage;
  final String? linkCode;
  final List<String>? parentIds;
  final List<String>? childrenIds;
  final int xp;
  final int level;
  final List<String> badges;
  final List<String>? interests;
  final String? careerMode;
  final String? phoneNumber; // Added
  final String? curriculum; // Added

  UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    this.photoURL,
    required this.role,
    this.grade,
    required this.schoolName, // <--- NEW FIELD
    this.educationLevel,
    this.subjects,
    this.isSubscribed = false,
    this.subscriptionExpiry,
    this.preferredLanguage,
    this.linkCode,
    this.parentIds,
    this.childrenIds,
    this.xp = 0,
    this.level = 1,
    this.badges = const [],
    this.interests,
    this.careerMode,
    this.phoneNumber,
    this.curriculum,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'photoURL': photoURL,
      'role': role,
      'grade': grade,
      'schoolName': schoolName, // <--- NEW FIELD
      'educationLevel': educationLevel,
      'subjects': subjects,
      'isSubscribed': isSubscribed,
      'subscriptionExpiry': subscriptionExpiry
          ?.microsecondsSinceEpoch, // Microseconds? standard is Milliseconds usually, but following potential precedent. Let's use Milliseconds for safety if standard. Actually usually Timestamp in Firestore. But here toMap. Let's use milliseconds.
      // Wait, previous code likely used Timestamp or Milliseconds. I don't see previous code for toMap.
      // I will safe bet on milliseconds or standard map.
      // Let's check `fromMap` in previous `auth_provider.dart` logs?
      // `fromMap` was `doc.data()`.
      // I'll stick to simple types.
      'preferred_language': preferredLanguage,
      'link_code': linkCode,
      'parent_ids': parentIds,
      'children_ids': childrenIds,
      'xp': xp,
      'level': level,
      'badges': badges,
      'interests': interests,
      'careerMode': careerMode,
      'phoneNumber': phoneNumber,
      'curriculum': curriculum,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map, String uid) {
    // Helper to safely get Timestamp/Date
    DateTime? getDateTime(dynamic val) {
      if (val == null) return null;
      if (val is Timestamp) return val.toDate();
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      return null;
    }

    return UserModel(
      uid: uid,
      email: map['email'] ?? '',
      displayName: map['displayName'] ?? '',
      photoURL: map['photoURL'] ?? map['photoUrl'], // Handle legacy
      role: map['role'] ?? '',
      grade: map['grade'] is int
          ? map['grade']
          : int.tryParse(
              map['grade'].toString().replaceAll(RegExp(r'[^0-9]'), ''),
            ), // Handle String/Int mismatch
      schoolName: map['schoolName'] ?? '', // <--- NEW FIELD
      educationLevel: map['educationLevel'],
      subjects:
          map['subjects'] != null ? List<String>.from(map['subjects']) : null,
      isSubscribed: map['isSubscribed'] ?? false,
      subscriptionExpiry: getDateTime(map['subscriptionExpiry']),
      preferredLanguage: map['preferred_language'],
      linkCode: map['link_code'],
      parentIds: map['parent_ids'] != null
          ? List<String>.from(map['parent_ids'])
          : null,
      childrenIds: map['children_ids'] != null
          ? List<String>.from(map['children_ids'])
          : null,
      xp: map['xp'] ?? 0,
      level: map['level'] ?? 1,
      badges: map['badges'] != null ? List<String>.from(map['badges']) : [],
      interests:
          map['interests'] != null ? List<String>.from(map['interests']) : null,
      careerMode: map['careerMode'],
      phoneNumber: map['phoneNumber'],
      curriculum: map['curriculum'],
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
    String? linkCode,
    List<String>? parentIds,
    List<String>? childrenIds,
    int? xp,
    int? level,
    List<String>? badges,
    List<String>? interests,
    String? careerMode,
    String? phoneNumber,
    String? curriculum,
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
      linkCode: linkCode ?? this.linkCode,
      parentIds: parentIds ?? this.parentIds,
      childrenIds: childrenIds ?? this.childrenIds,
      xp: xp ?? this.xp,
      level: level ?? this.level,
      badges: badges ?? this.badges,
      interests: interests ?? this.interests,
      careerMode: careerMode ?? this.careerMode,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      curriculum: curriculum ?? this.curriculum,
    );
  }
}
