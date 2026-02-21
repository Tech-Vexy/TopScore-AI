import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Manages a user's daily learning streak.
/// Called on app open to update and read streak data.
class StreakService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static final StreakService _instance = StreakService._internal();
  factory StreakService() => _instance;
  StreakService._internal();

  /// Updates the streak for a user and returns current streak count.
  Future<int> updateAndGetStreak(String uid) async {
    try {
      final ref = _firestore.collection('user_streaks').doc(uid);
      final doc = await ref.get();

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      if (!doc.exists) {
        // First time — create streak doc
        await ref.set({
          'currentStreak': 1,
          'longestStreak': 1,
          'lastActiveDate': today.toIso8601String(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return 1;
      }

      final data = doc.data()!;
      final lastActiveStr = data['lastActiveDate'] as String?;
      final currentStreak = (data['currentStreak'] as int?) ?? 0;
      final longestStreak = (data['longestStreak'] as int?) ?? 0;

      if (lastActiveStr == null) {
        await ref.update(
            {'currentStreak': 1, 'lastActiveDate': today.toIso8601String()});
        return 1;
      }

      final lastActive = DateTime.parse(lastActiveStr);
      final lastActiveDay =
          DateTime(lastActive.year, lastActive.month, lastActive.day);
      final diff = today.difference(lastActiveDay).inDays;

      if (diff == 0) {
        // Already visited today — no change
        return currentStreak;
      } else if (diff == 1) {
        // Consecutive day — increment streak
        final newStreak = currentStreak + 1;
        await ref.update({
          'currentStreak': newStreak,
          'longestStreak':
              newStreak > longestStreak ? newStreak : longestStreak,
          'lastActiveDate': today.toIso8601String(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return newStreak;
      } else {
        // Streak broken — reset
        await ref.update({
          'currentStreak': 1,
          'lastActiveDate': today.toIso8601String(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return 1;
      }
    } catch (e) {
      debugPrint('❌ StreakService error: $e');
      return 0;
    }
  }

  /// Get the current streak count without updating it.
  Future<int> getStreak(String uid) async {
    try {
      final doc = await _firestore.collection('user_streaks').doc(uid).get();
      if (!doc.exists) return 0;
      return (doc.data()?['currentStreak'] as int?) ?? 0;
    } catch (e) {
      return 0;
    }
  }

  /// Get longest streak ever.
  Future<int> getLongestStreak(String uid) async {
    try {
      final doc = await _firestore.collection('user_streaks').doc(uid).get();
      if (!doc.exists) return 0;
      return (doc.data()?['longestStreak'] as int?) ?? 0;
    } catch (e) {
      return 0;
    }
  }
}
