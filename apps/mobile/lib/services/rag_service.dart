import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

class RagService {
  final _db = FirebaseDatabase.instance.ref();

  /// Fetches simple RAG context (all chunks) from RTDB.
  /// Limitation: This fetches ALL 'knowledge' nodes.
  /// In a real production app with Vector Search, this would hit an API endpoint.
  /// For this MVP, we fetch the last 20 chunks to keep context manageable.
  Future<String> fetchRagContext() async {
    try {
      final snapshot = await _db.child('knowledge').limitToLast(20).get();

      if (!snapshot.exists) {
        return "";
      }

      final StringBuffer contextBuffer = StringBuffer();
      contextBuffer.writeln(
        "Here is some relevant context from the teacher's notes:",
      );

      for (final child in snapshot.children) {
        final data = child.value as Map<dynamic, dynamic>;
        final String text = data['text'] ?? '';
        final Map<dynamic, dynamic> metadata = data['metadata'] ?? {};
        final String source = metadata['filename'] ?? 'General Knowledge';

        if (text.isNotEmpty) {
          contextBuffer.writeln("- (Source: $source): $text");
        }
      }

      return contextBuffer.toString();
    } catch (e) {
      debugPrint("Error fetching RAG context: $e");
      return "";
    }
  }
}
