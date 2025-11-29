import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/resource_model.dart';
import '../models/user_model.dart';
import '../models/support_ticket_model.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<ResourceModel>> getResources(int grade, {String? subject}) async {
    Query query = _firestore.collection('resources').where('grade', isEqualTo: grade);
    
    if (subject != null) {
      query = query.where('subject', isEqualTo: subject);
    }

    QuerySnapshot snapshot = await query.get();
    return snapshot.docs.map((doc) => ResourceModel.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList();
  }

  Future<void> createUser(UserModel user) async {
    await _firestore.collection('users').doc(user.uid).set(user.toMap());
  }

  Future<UserModel?> getUser(String uid) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return UserModel.fromMap(doc.data() as Map<String, dynamic>, uid);
      }
      return null;
    } catch (e) {
      print("Error getting user: $e");
      // If permission denied, we might want to return null or rethrow
      // For now, let's return null so the app doesn't crash, but the user might need to sign in again or we handle it in AuthProvider
      if (e.toString().contains('permission-denied')) {
        print("PERMISSION DENIED: Please check your Firestore Security Rules.");
      }
      rethrow;
    }
  }

  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    await _firestore.collection('users').doc(uid).set(data, SetOptions(merge: true));
  }

  // Chat History
  Future<void> saveChatMessage(String userId, Map<String, dynamic> messageData) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('chat_history')
        .add({
          ...messageData,
          'timestamp': FieldValue.serverTimestamp(),
        });
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
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => SupportTicket.fromMap(doc.data(), doc.id))
            .toList());
  }
}
