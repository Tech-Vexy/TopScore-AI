import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String? email;
  final String? displayName;
  final String? photoURL;
  final String? role;
  final String? educationLevel;
  final int? grade;
  final List<String>? subjects;
  final bool isSubscribed;
  final DateTime? subscriptionExpiry;

  UserModel({
    required this.uid,
    this.email,
    this.displayName,
    this.photoURL,
    this.role,
    this.educationLevel,
    this.grade,
    this.subjects,
    this.isSubscribed = false,
    this.subscriptionExpiry,
  });

  factory UserModel.fromMap(Map<String, dynamic> data, String uid) {
    return UserModel(
      uid: uid,
      email: data['email'],
      displayName: data['displayName'],
      photoURL: data['photoURL'],
      role: data['role'],
      educationLevel: data['educationLevel'],
      grade: data['grade'],
      subjects: data['subjects'] != null ? List<String>.from(data['subjects']) : null,
      isSubscribed: data['isSubscribed'] ?? false,
      subscriptionExpiry: data['subscriptionExpiry'] != null 
          ? (data['subscriptionExpiry'] as Timestamp).toDate() 
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'displayName': displayName,
      'photoURL': photoURL,
      'role': role,
      'educationLevel': educationLevel,
      'grade': grade,
      'subjects': subjects,
      'isSubscribed': isSubscribed,
      'subscriptionExpiry': subscriptionExpiry,
    };
  }

  @override
  String toString() {
    return 'UserModel(uid: $uid, email: $email, displayName: $displayName, role: $role)';
  }
}
