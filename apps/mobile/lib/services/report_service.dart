import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Weekly activity report for a child — used in Parent dashboard.
class WeeklyReport {
  final String childUid;
  final String childName;
  final int aiSessionCount;
  final int resourcesOpened;
  final int daysActive;
  final Map<String, int> activityByDay; // e.g. {"Mon": 3, "Tue": 5}
  final List<String> topTopics;
  final DateTime generatedAt;

  const WeeklyReport({
    required this.childUid,
    required this.childName,
    required this.aiSessionCount,
    required this.resourcesOpened,
    required this.daysActive,
    required this.activityByDay,
    required this.topTopics,
    required this.generatedAt,
  });
}

/// Aggregates Firestore activity data for a child over the past 7 days.
class ReportService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static final ReportService _instance = ReportService._internal();
  factory ReportService() => _instance;
  ReportService._internal();

  Future<WeeklyReport> generateWeeklyReport(
      String childUid, String childName) async {
    try {
      final now = DateTime.now();
      final weekAgo = now.subtract(const Duration(days: 7));
      final weekAgoTs = Timestamp.fromDate(weekAgo);

      // Fetch raw activity
      final snap = await _db
          .collection('user_activity')
          .where('userId', isEqualTo: childUid)
          .where('timestamp', isGreaterThan: weekAgoTs)
          .orderBy('timestamp', descending: false)
          .get();

      final docs = snap.docs;
      int resourcesOpened = 0;
      int aiSessions = 0;
      final Set<String> activeDays = {};
      final Map<String, int> activityByDay = {};
      final Map<String, int> topicCounts = {};

      for (final doc in docs) {
        final data = doc.data();
        final ts = (data['timestamp'] as Timestamp?)?.toDate();
        if (ts == null) continue;

        final dayKey = _dayAbbrev(ts.weekday);
        activityByDay[dayKey] = (activityByDay[dayKey] ?? 0) + 1;
        activeDays.add('${ts.year}-${ts.month}-${ts.day}');

        final action = data['action'] as String? ?? '';
        if (action == 'open_file') resourcesOpened++;
        if (action == 'ai_query') aiSessions++;

        final topic = data['topic'] as String?;
        if (topic != null && topic.isNotEmpty) {
          topicCounts[topic] = (topicCounts[topic] ?? 0) + 1;
        }
      }

      // Sort and pick top 3 topics
      final sortedTopics = topicCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final topTopics = sortedTopics.take(3).map((e) => e.key).toList();

      return WeeklyReport(
        childUid: childUid,
        childName: childName,
        aiSessionCount: aiSessions,
        resourcesOpened: resourcesOpened,
        daysActive: activeDays.length,
        activityByDay: activityByDay,
        topTopics: topTopics,
        generatedAt: now,
      );
    } catch (e) {
      debugPrint('❌ ReportService error: $e');
      return WeeklyReport(
        childUid: childUid,
        childName: childName,
        aiSessionCount: 0,
        resourcesOpened: 0,
        daysActive: 0,
        activityByDay: {},
        topTopics: [],
        generatedAt: DateTime.now(),
      );
    }
  }

  String _dayAbbrev(int weekday) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[(weekday - 1).clamp(0, 6)];
  }
}
