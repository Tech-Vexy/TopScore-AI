import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/resource_model.dart';
import '../models/user_model.dart';
import '../models/support_ticket_model.dart';

/// Result returned from paginated queries.
class PaginatedResult<T> {
  final List<T> items;
  final DocumentSnapshot? lastDoc; // null when no more pages
  final bool hasMore;

  const PaginatedResult({
    required this.items,
    required this.lastDoc,
    required this.hasMore,
  });
}

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<ResourceModel>> getResources(int grade,
      {String? subject, String? curriculum}) async {
    final collectionName = _getCollectionName(curriculum);
    Query query =
        _firestore.collection(collectionName).where('grade', isEqualTo: grade);

    if (subject != null) {
      query = query.where('subject', isEqualTo: subject);
    }

    QuerySnapshot snapshot = await query.get();
    return snapshot.docs
        .map(
          (doc) =>
              ResourceModel.fromMap(doc.data() as Map<String, dynamic>, doc.id),
        )
        .toList();
  }

  /// Fetch a page of resources for a given grade/subject.
  /// [lastDoc] is the last document from the previous page (for cursor pagination).
  Future<PaginatedResult<ResourceModel>> getPaginatedResources(
    int grade, {
    String? subject,
    String? curriculum,
    String? collection,
    DocumentSnapshot? lastDoc,
    int limit = 20,
  }) async {
    try {
      final collectionName = collection ?? _getCollectionName(curriculum);
      Query query = _firestore
          .collection(collectionName)
          .where('grade', isEqualTo: grade)
          .orderBy('title')
          .limit(limit + 1); // fetch one extra to detect hasMore

      if (subject != null) query = query.where('subject', isEqualTo: subject);
      if (lastDoc != null) query = query.startAfterDocument(lastDoc);

      final snap = await query.get();
      final hasMore = snap.docs.length > limit;
      final docs = hasMore ? snap.docs.sublist(0, limit) : snap.docs;

      return PaginatedResult(
        items: docs
            .map((d) =>
                ResourceModel.fromMap(d.data() as Map<String, dynamic>, d.id))
            .toList(),
        lastDoc: docs.isNotEmpty ? docs.last : null,
        hasMore: hasMore,
      );
    } catch (e) {
      debugPrint('❌ getPaginatedResources error: $e');
      return const PaginatedResult(items: [], lastDoc: null, hasMore: false);
    }
  }

  Future<List<ResourceModel>> getRecentDriveResources(int limit,
      {String? curriculum}) async {
    try {
      final collectionName = _getCollectionName(curriculum);
      Query query = _firestore
          .collection(collectionName)
          .where('source', isEqualTo: 'google_drive')
          .orderBy('createdAt', descending: true)
          .limit(limit);

      QuerySnapshot snapshot = await query.get();
      return snapshot.docs
          .map(
            (doc) => ResourceModel.fromMap(
              doc.data() as Map<String, dynamic>,
              doc.id,
            ),
          )
          .toList();
    } catch (e) {
      debugPrint("Error fetching recent drive resources: $e");
      return [];
    }
  }

  Future<void> createUser(UserModel user) async {
    await _firestore.collection('users').doc(user.uid).set(user.toMap());
  }

  Future<UserModel?> getUser(String uid) async {
    try {
      DocumentSnapshot doc =
          await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return UserModel.fromMap(doc.data() as Map<String, dynamic>, uid);
      }
      return null;
    } catch (e) {
      debugPrint("Error getting user: $e");
      // If permission denied, we might want to return null or rethrow
      // For now, let's return null so the app doesn't crash, but the user might need to sign in again or we handle it in AuthProvider
      if (e.toString().contains('permission-denied')) {
        debugPrint(
          "PERMISSION DENIED: Please check your Firestore Security Rules.",
        );
      }
      rethrow;
    }
  }

  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .set(data, SetOptions(merge: true));
  }

  Future<List<UserModel>> getChildren(List<String> childrenIds) async {
    if (childrenIds.isEmpty) return [];

    try {
      // Create chunks of 10 IDs to avoid Firestore 'in' limit of 10
      List<List<String>> chunks = [];
      for (var i = 0; i < childrenIds.length; i += 10) {
        chunks.add(
          childrenIds.sublist(
            i,
            i + 10 > childrenIds.length ? childrenIds.length : i + 10,
          ),
        );
      }

      List<UserModel> children = [];
      for (var chunk in chunks) {
        final snapshot = await _firestore
            .collection('users')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();

        children.addAll(
          snapshot.docs.map((doc) => UserModel.fromMap(doc.data(), doc.id)),
        );
      }
      return children;
    } catch (e) {
      debugPrint("Error fetching children: $e");
      return [];
    }
  }

  // Chat History
  Future<void> saveChatMessage(
    String userId,
    Map<String, dynamic> messageData,
  ) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('chat_history')
        .add({...messageData, 'timestamp': FieldValue.serverTimestamp()});
  }

  Future<List<Map<String, dynamic>>> getChatHistory(String userId) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('chat_history')
        .orderBy('timestamp', descending: false)
        .get();

    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  // Support Tickets
  Future<void> createSupportTicket(SupportTicket ticket) async {
    await _firestore.collection('support_tickets').add(ticket.toMap());
  }

  Stream<List<SupportTicket>> getUserSupportTickets(String userId) {
    return _firestore
        .collection('support_tickets')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snapshot) {
      final tickets = snapshot.docs
          .map((doc) => SupportTicket.fromMap(doc.data(), doc.id))
          .toList();
      // Sort client-side to avoid composite index requirement
      tickets.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return tickets;
    });
  }

  // Activity Tracking
  Future<void> trackFileOpen({
    required String userId,
    required String fileName,
    required String filePath,
    String? fileType,
  }) async {
    try {
      await _firestore.collection('user_activity').add({
        'userId': userId,
        'action': 'open_file',
        'fileName': fileName,
        'filePath': filePath,
        'fileType': fileType ?? 'unknown',
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint("Error tracking file open: $e");
    }
  }

  // Helper for dynamic collection naming
  String _getCollectionName(String? curriculum) {
    if (curriculum == null || curriculum.isEmpty) return 'cbc_files';
    final upper = curriculum.toUpperCase().trim();
    if (upper == '8.4.4' ||
        upper == '844' ||
        upper == '8-4-4' ||
        upper == 'KCSE') {
      return '844_files';
    }
    return 'cbc_files';
  }
}
