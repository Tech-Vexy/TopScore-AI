import 'package:cloud_firestore/cloud_firestore.dart';

class SupportTicket {
  final String id;
  final String userId;
  final String subject;
  final String message;
  final String status; // 'open', 'resolved', 'closed'
  final DateTime createdAt;
  final String? reply;

  SupportTicket({
    required this.id,
    required this.userId,
    required this.subject,
    required this.message,
    this.status = 'open',
    required this.createdAt,
    this.reply,
  });

  factory SupportTicket.fromMap(Map<String, dynamic> data, String id) {
    return SupportTicket(
      id: id,
      userId: data['userId'] ?? '',
      subject: data['subject'] ?? '',
      message: data['message'] ?? '',
      status: data['status'] ?? 'open',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      reply: data['reply'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'subject': subject,
      'message': message,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'reply': reply,
    };
  }
}
