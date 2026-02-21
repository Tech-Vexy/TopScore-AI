import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

/// Centralized analytics service wrapping Firebase Analytics.
///
/// Usage:
///   AnalyticsService.instance.logScreenView('home');
///   AnalyticsService.instance.logEvent('button_tap', {'label': 'start_quiz'});
///   AnalyticsService.instance.setUserId('uid_123');
class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService instance = AnalyticsService._();

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  /// Navigator observer for automatic screen tracking with go_router.
  FirebaseAnalyticsObserver get observer =>
      FirebaseAnalyticsObserver(analytics: _analytics);

  // ── User Properties ───────────────────────────────────────────────────────

  Future<void> setUserId(String? uid) async {
    await _analytics.setUserId(id: uid);
  }

  Future<void> setUserRole(String role) async {
    await _analytics.setUserProperty(name: 'role', value: role);
  }

  Future<void> setSubscriptionTier(String tier) async {
    await _analytics.setUserProperty(name: 'subscription_tier', value: tier);
  }

  // ── Screen Tracking ───────────────────────────────────────────────────────

  Future<void> logScreenView(String screenName, {String? screenClass}) async {
    await _analytics.logScreenView(
      screenName: screenName,
      screenClass: screenClass ?? screenName,
    );
  }

  // ── Auth Events ───────────────────────────────────────────────────────────

  Future<void> logLogin(String method) async {
    await _analytics.logLogin(loginMethod: method);
  }

  Future<void> logSignUp(String method) async {
    await _analytics.logSignUp(signUpMethod: method);
  }

  // ── Learning Events ───────────────────────────────────────────────────────

  Future<void> logStartStudySession({
    required String subject,
    required String topic,
  }) async {
    await _analytics.logEvent(
      name: 'start_study_session',
      parameters: {'subject': subject, 'topic': topic},
    );
  }

  Future<void> logCompleteQuiz({
    required String quizId,
    required int score,
    required int totalQuestions,
  }) async {
    await _analytics.logEvent(
      name: 'complete_quiz',
      parameters: {
        'quiz_id': quizId,
        'score': score,
        'total_questions': totalQuestions,
        'percentage': (score / totalQuestions * 100).round(),
      },
    );
  }

  Future<void> logAiTutorMessage({required String messageType}) async {
    await _analytics.logEvent(
      name: 'ai_tutor_message',
      parameters: {'message_type': messageType},
    );
  }

  Future<void> logResourceView({
    required String resourceId,
    required String resourceType,
  }) async {
    await _analytics.logEvent(
      name: 'resource_view',
      parameters: {
        'resource_id': resourceId,
        'resource_type': resourceType,
      },
    );
  }

  Future<void> logToolUsed(String toolName) async {
    await _analytics.logEvent(
      name: 'tool_used',
      parameters: {'tool_name': toolName},
    );
  }

  Future<void> logDownloadResource(String resourceId) async {
    await _analytics.logEvent(
      name: 'download_resource',
      parameters: {'resource_id': resourceId},
    );
  }

  Future<void> logStreakUpdate(int streakDays) async {
    await _analytics.logEvent(
      name: 'streak_update',
      parameters: {'streak_days': streakDays},
    );
  }

  // ── Generic Event ─────────────────────────────────────────────────────────

  Future<void> logEvent(
    String name, [
    Map<String, Object>? parameters,
  ]) async {
    await _analytics.logEvent(name: name, parameters: parameters);
  }

  // ── Debug ─────────────────────────────────────────────────────────────────

  /// Enable verbose analytics logging in debug builds.
  Future<void> enableDebugMode() async {
    if (kDebugMode) {
      await _analytics.setAnalyticsCollectionEnabled(true);
    }
  }
}
