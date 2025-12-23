import 'package:cloud_firestore/cloud_firestore.dart';

class ResourceModel {
  final String id;
  final String title;
  final String type; // 'past_paper', 'notes', 'topical', 'mock'
  final String subject;
  final int grade;
  final int? year;
  final String curriculum; // 'KCPE', 'KCSE', 'CBC'
  final String downloadUrl;
  final int fileSize;
  final bool premium;
  final String? source;
  final DateTime? createdAt;

  ResourceModel({
    required this.id,
    required this.title,
    required this.type,
    required this.subject,
    required this.grade,
    this.year,
    required this.curriculum,
    required this.downloadUrl,
    required this.fileSize,
    required this.premium,
    this.source,
    this.createdAt,
  });

  factory ResourceModel.fromMap(Map<String, dynamic> data, String id) {
    return ResourceModel(
      id: id,
      title: data['title'] ?? '',
      type: data['type'] ?? 'notes',
      subject: data['subject'] ?? '',
      grade: data['grade'] ?? 0,
      year: data['year'],
      curriculum: data['curriculum'] ?? 'CBC',
      downloadUrl: data['downloadUrl'] ?? '',
      fileSize: data['fileSize'] ?? 0,
      premium: data['premium'] ?? false,
      source: data['source'],
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
    );
  }
}
