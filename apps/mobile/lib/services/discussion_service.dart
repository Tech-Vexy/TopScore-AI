import 'dart:convert';
import 'dart:math'; // For random delays
import 'package:firebase_database/firebase_database.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/user_model.dart';

class DiscussionService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  String get _aiBackendUrl => '${ApiConfig.baseUrl}/api/chat/group_moderator';

  String _generateMeetingCode() {
    return (100000 + DateTime.now().millisecondsSinceEpoch % 900000).toString();
  }

  // --- 1. Create Meeting with AI Member ---
  Future<String?> createMeeting(
    String topic,
    UserModel host,
    int durationMinutes,
  ) async {
    final meetingId = _generateMeetingCode();
    final meetingRef = _db.child('meetings/$meetingId');

    // Calculate End Time
    final startTime = DateTime.now();
    final endTime = startTime.add(Duration(minutes: durationMinutes));

    final meetingData = {
      'id': meetingId,
      'topic': topic,
      'hostId': host.uid,
      'status': 'active',
      'createdAt': startTime.millisecondsSinceEpoch,
      'endsAt': endTime.millisecondsSinceEpoch,
      'durationMinutes': durationMinutes,
      'participants': {
        host.uid: {
          'id': host.uid,
          'name': host.displayName,
          'role': 'host',
          'isHandRaised': false,
          'isMicOn': true,
          'isCamOn': false,
          'joinedAt': ServerValue.timestamp,
        },
        // 🤖 THE AI AGENT AUTOMATICALLY JOINS HERE
        'ai_tutor_bot': {
          'id': 'ai_tutor_bot',
          'name': 'AI Moderator',
          'role': 'bot',
          'isHandRaised': false,
          'isMicOn': true, // Always "listening"
          'isCamOn': true, // "Present" in the grid
          'joinedAt': ServerValue.timestamp,
        },
      },
    };

    await meetingRef.set(meetingData);

    // 🤖 AI sends the opening remark
    await sendMessage(
      meetingId,
      'ai_tutor_bot',
      'AI Moderator',
      "Hello everyone! I'm here to help guide your discussion on '$topic'. I won't give you the answers, but I'll ask questions to help you figure them out together. Who wants to start?",
    );

    return meetingId;
  }

  // --- 2. Join/Leave/State Logic (Standard) ---
  Future<bool> joinMeeting(String meetingId, UserModel user) async {
    final meetingRef = _db.child('meetings/$meetingId');
    final snapshot = await meetingRef.get();
    if (!snapshot.exists) return false;

    await meetingRef.child('participants/${user.uid}').set({
      'id': user.uid,
      'name': user.displayName,
      'role': 'attendee',
      'isHandRaised': false,
      'isMicOn': false,
      'isCamOn': false,
      'joinedAt': ServerValue.timestamp,
    });
    return true;
  }

  Future<void> leaveMeeting(String meetingId, String userId) async {
    await _db.child('meetings/$meetingId/participants/$userId').remove();
  }

  Future<void> toggleHandRaise(
    String meetingId,
    String userId,
    bool isRaised,
  ) async {
    await _db.child('meetings/$meetingId/participants/$userId').update({
      'isHandRaised': isRaised,
    });
  }

  Future<void> updateMediaState(
    String meetingId,
    String userId, {
    bool? isMicOn,
    bool? isCamOn,
  }) async {
    final updates = <String, dynamic>{};
    if (isMicOn != null) updates['isMicOn'] = isMicOn;
    if (isCamOn != null) updates['isCamOn'] = isCamOn;
    if (updates.isNotEmpty) {
      await _db
          .child('meetings/$meetingId/participants/$userId')
          .update(updates);
    }
  }

  // --- 3. Messaging with AI Trigger ---
  Future<void> sendMessage(
    String meetingId,
    String userId,
    String userName,
    String text,
  ) async {
    // 1. Save User Message
    final messageRef = _db.child('meetings/$meetingId/chat').push();
    await messageRef.set({
      'senderId': userId,
      'senderName': userName,
      'text': text,
      'timestamp': ServerValue.timestamp,
    });

    // 2. Check if AI should respond
    // Trigger if explicitly tagged OR (optional) randomly interject
    bool isTagged = text.toLowerCase().contains('@ai') ||
        text.toLowerCase().contains('tutor');

    if (isTagged) {
      _triggerAiResponse(meetingId, text, userName);
    }
  }

  // --- 4. The Socratic Logic ---
  Future<void> _triggerAiResponse(
    String meetingId,
    String userMessage,
    String senderName,
  ) async {
    try {
      // Simulate "Typing" delay to feel natural
      await Future.delayed(Duration(seconds: 1 + Random().nextInt(2)));

      // Fetch recent chat history context (last 5 messages)
      // This allows the AI to understand the flow of the conversation
      // (Implementation skipped for brevity, but you'd query Firebase here)

      final response = await http.post(
        Uri.parse(_aiBackendUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'meeting_id': meetingId,
          'user_message': userMessage,
          'sender_name': senderName,
          'mode': 'socratic_tutor', // 🔑 KEY: Tells backend to be Socratic
          'instruction':
              'Do not give the direct answer. Ask a guiding question based on the user input. Encourage peer discussion.',
        }),
      );

      String aiReply;
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        aiReply = data['message'];
      } else {
        aiReply =
            "That's an interesting point, $senderName. Does anyone else have thoughts on this?";
      }

      // Send AI Reply
      final aiMsgRef = _db.child('meetings/$meetingId/chat').push();
      await aiMsgRef.set({
        'senderId': 'ai_tutor_bot',
        'senderName': 'AI Moderator',
        'text': aiReply,
        'timestamp': ServerValue.timestamp,
        'isAi': true, // Flag for UI styling
      });
    } catch (e) {
      // Fail gracefully
      // ignore: avoid_print
      print("AI Error: $e");
    }
  }

  // --- 5. Streams ---
  Stream<Map<String, dynamic>?> streamMeeting(String meetingId) {
    return _db.child('meetings/$meetingId').onValue.map((event) {
      if (!event.snapshot.exists || event.snapshot.value == null) return null;
      try {
        final data = jsonDecode(jsonEncode(event.snapshot.value));
        return Map<String, dynamic>.from(data);
      } catch (e) {
        return null;
      }
    });
  }

  Stream<List<Map<String, dynamic>>> streamChat(String meetingId) {
    return _db
        .child('meetings/$meetingId/chat')
        .orderByChild('timestamp')
        .limitToLast(50)
        .onValue
        .map((event) {
      if (!event.snapshot.exists || event.snapshot.value == null) return [];
      final Map<dynamic, dynamic> rawData =
          event.snapshot.value as Map<dynamic, dynamic>;
      final List<Map<String, dynamic>> messages = [];
      rawData.forEach((key, value) {
        messages.add(Map<String, dynamic>.from(value));
      });
      messages.sort(
        (a, b) => (a['timestamp'] as int).compareTo(b['timestamp'] as int),
      );
      return messages;
    });
  }
}
