import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/foundation.dart';
import 'dart:async';

class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  // New: Stream for navigation events
  final StreamController<String> _navigationStream =
      StreamController<String>.broadcast();
  Stream<String> get navigationStream => _navigationStream.stream;

  Future<void> initialize() async {
    // Initialize Timezones for scheduling
    tz.initializeTimeZones();

    // Setup Local Notifications
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    // Initialize with Callback
    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.payload != null) {
          debugPrint("Notification Tapped: ${response.payload}");
          _navigationStream.add(response.payload!);
        }
      },
    );
  }

  Future<void> requestPermissions() async {
    // Request Permissions for Firebase Messaging
    await _fcm.requestPermission(alert: true, badge: true, sound: true);

    // Request Permissions for Local Notifications (iOS)
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  /// Schedule a weekly reminder for a class
  Future<void> scheduleClassReminder({
    required int id,
    required String title,
    required String body,
    required String dayName, // e.g., "Monday"
    required String timeString, // e.g., "08:00 AM"
  }) async {
    try {
      final tz.TZDateTime now = tz.TZDateTime.now(tz.local);

      // 1. Parse the Time (e.g., "08:00 AM")
      final timeParts = timeString.split(' '); // ["08:00", "AM"]
      final hm = timeParts[0].split(':');
      int hour = int.parse(hm[0]);
      int minute = int.parse(hm[1]);
      if (timeParts[1] == "PM" && hour != 12) hour += 12;
      if (timeParts[1] == "AM" && hour == 12) hour = 0;

      // 2. Find the next occurrence of the specific Day
      int targetWeekday = _getWeekdayIndex(dayName); // 1 = Mon, 7 = Sun

      tz.TZDateTime scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );

      // Adjust to the correct day of week
      while (scheduledDate.weekday != targetWeekday) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      // If the calculated time is in the past, move to next week
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 7));
      }

      // 3. Subtract 10 minutes for the "Reminder" (Notify before class starts)
      scheduledDate = scheduledDate.subtract(const Duration(minutes: 10));

      // 4. Schedule It
      await _localNotifications.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'timetable_channel',
            'Timetable Reminders',
            channelDescription: 'Reminders for upcoming classes',
            importance: Importance.max,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        // ignore: missing_required_param
        matchDateTimeComponents:
            DateTimeComponents.dayOfWeekAndTime, // Repeats weekly
        payload: '/timetable', // Route to open
      );

      debugPrint(
        "✅ Scheduled $title for $dayName at $timeString (Next: $scheduledDate)",
      );
    } catch (e) {
      debugPrint("❌ Error scheduling notification: $e");
    }
  }

  Future<void> cancelNotification(int id) async {
    await _localNotifications.cancel(id);
  }

  static const int _inactivityNotificationId = 999;
  static const String _generalTopic = 'general_updates';

  /// Call this when the app starts or resumes
  Future<void> onAppUsage() async {
    // 1. Cancel any pending "we miss you" notification
    await cancelNotification(_inactivityNotificationId);

    // 2. Schedule a new one for 24 hours from now
    await scheduleInactivityReminder();
  }

  /// Schedule a notification if the user hasn't opened the app for 24 hours
  Future<void> scheduleInactivityReminder() async {
    if (kIsWeb) return; // Not supported on web
    try {
      final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
      final tz.TZDateTime scheduledDate = now.add(const Duration(hours: 24));

      await _localNotifications.zonedSchedule(
        _inactivityNotificationId,
        "We miss you! 🎓",
        "You haven't studied in a day. Keep your streak alive to ace your exams!",
        scheduledDate,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'inactivity_channel',
            'Inactivity Reminders',
            channelDescription: 'Reminders to keep studying',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        // ignore: missing_required_param
        // uiLocalNotificationDateInterpretation: omitted to fix web build error
      );
      debugPrint("✅ Scheduled inactivity reminder for $scheduledDate");
    } catch (e) {
      debugPrint("❌ Error scheduling inactivity reminder: $e");
    }
  }

  /// Initialize FCM Listeners for "New Feature" / "New File" alerts
  Future<void> initializeFCMListeners() async {
    // Subscribe to general topic (Not supported on Web)
    if (!kIsWeb) {
      try {
        await _fcm.subscribeToTopic(_generalTopic);
        debugPrint("✅ Subscribed to $_generalTopic");
      } catch (e) {
        debugPrint("❌ Error subscribing to topic: $e");
      }
    }

    // Handle Foreground Messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint(
        "📩 Received Foreground Notification: ${message.notification?.title}",
      );

      // Show as local notification immediately
      if (message.notification != null) {
        final androidDetails = const AndroidNotificationDetails(
          'updates_channel',
          'App Updates',
          channelDescription: 'Notifications about new features and files',
          importance: Importance.max,
          priority: Priority.high,
        );
        final iOSDetails = const DarwinNotificationDetails();
        final details = NotificationDetails(
          android: androidDetails,
          iOS: iOSDetails,
        );

        _localNotifications.show(
          message.hashCode,
          message.notification!.title,
          message.notification!.body,
          details,
        );
      }
    });
  }

  int _getWeekdayIndex(String day) {
    switch (day) {
      case 'Monday':
        return 1;
      case 'Tuesday':
        return 2;
      case 'Wednesday':
        return 3;
      case 'Thursday':
        return 4;
      case 'Friday':
        return 5;
      case 'Saturday':
        return 6;
      case 'Sunday':
        return 7;
      default:
        return 1;
    }
  }
}
