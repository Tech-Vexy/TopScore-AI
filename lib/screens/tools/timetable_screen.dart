import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'dart:math'; // For generating Notification IDs

// Import services
import '../../providers/auth_provider.dart';
import '../../services/notification_service.dart';

class TimetableScreen extends StatefulWidget {
  const TimetableScreen({super.key});

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final NotificationService _notificationService =
      NotificationService(); // Service Instance

  final List<String> _days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _days.length, vsync: this);
    _notificationService.initialize(); // Ensure notifications are ready
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _addClass(BuildContext context, String userId) {
    String subject = '';
    String startTime = '08:00 AM';
    String endTime = '09:00 AM';
    String selectedDay = _days[_tabController.index];

    final TextEditingController startCtrl = TextEditingController(
      text: startTime,
    );
    final TextEditingController endCtrl = TextEditingController(text: endTime);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          "Add Class",
          style: GoogleFonts.nunito(fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(
                  labelText: "Subject",
                  prefixIcon: Icon(Icons.book),
                ),
                onChanged: (val) => subject = val,
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                // ignore: deprecated_member_use
                value: selectedDay,
                items: _days
                    .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                    .toList(),
                onChanged: (val) => selectedDay = val!,
                decoration: const InputDecoration(labelText: "Day"),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: startCtrl,
                decoration: const InputDecoration(
                  labelText: "Start Time",
                  prefixIcon: Icon(Icons.access_time),
                ),
                onChanged: (val) => startTime = val,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: endCtrl,
                decoration: const InputDecoration(
                  labelText: "End Time",
                  prefixIcon: Icon(Icons.access_time_filled),
                ),
                onChanged: (val) => endTime = val,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              if (subject.isNotEmpty) {
                // Generate a unique numeric ID for the notification
                int notificationId = Random().nextInt(100000);

                final newClassKey = FirebaseDatabase.instance
                    .ref('users/$userId/timetable/$selectedDay')
                    .push()
                    .key;

                if (newClassKey != null) {
                  // 1. Save to Firebase
                  FirebaseDatabase.instance
                      .ref('users/$userId/timetable/$selectedDay/$newClassKey')
                      .set({
                        'id': newClassKey,
                        'notificationId':
                            notificationId, // Save ID to cancel later
                        'subject': subject,
                        'startTime': startTime,
                        'endTime': endTime,
                      });

                  // 2. Schedule Notification
                  _notificationService.scheduleClassReminder(
                    id: notificationId,
                    title: "Upcoming: $subject",
                    body:
                        "Your $subject class starts at $startTime. Get ready!",
                    dayName: selectedDay,
                    timeString: startTime,
                  );
                }
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Class added & Reminder set! ⏰"),
                  ),
                );
              }
            },
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).userModel;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Smart Timetable",
          style: GoogleFonts.nunito(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        backgroundColor: theme.scaffoldBackgroundColor,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF6C63FF),
          unselectedLabelColor: theme.disabledColor,
          isScrollable: true,
          tabs: _days.map((d) => Tab(text: d)).toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _days
            .map((day) => _DayView(userId: user.uid, day: day))
            .toList(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addClass(context, user.uid),
        backgroundColor: const Color(0xFF6C63FF),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _DayView extends StatelessWidget {
  final String userId;
  final String day;

  const _DayView({required this.userId, required this.day});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DatabaseEvent>(
      stream: FirebaseDatabase.instance
          .ref('users/$userId/timetable/$day')
          .onValue,
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.snapshot.exists) {
          // FIXED: Use exists instead of value check
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.calendar_today, size: 60, color: Colors.grey[300]),
                const SizedBox(height: 10),
                Text(
                  "No classes today. Enjoy! 🎉",
                  style: GoogleFonts.nunito(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        // FIXED: Use children iteration to avoid value deprecation
        final List<Map<String, dynamic>> classes = [];
        for (final child in snapshot.data!.snapshot.children) {
          // ignore: deprecated_member_use
          if (child.value != null && child.value is Map) {
            // ignore: deprecated_member_use
            classes.add(Map<String, dynamic>.from(child.value as Map));
          }
        }

        classes.sort(
          (a, b) =>
              (a['startTime'] as String).compareTo(b['startTime'] as String),
        );

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: classes.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final cls = classes[index];
            final theme = Theme.of(context);

            return Card(
              color: theme.cardColor,
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6C63FF).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const FaIcon(
                    FontAwesomeIcons.bookOpen,
                    color: Color(0xFF6C63FF),
                    size: 20,
                  ),
                ),
                // FIXED: Removed unnecessary string interpolation
                title: Text(
                  cls['subject'] ?? 'Unknown',
                  style: GoogleFonts.nunito(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                subtitle: Text(
                  "${cls['startTime']} - ${cls['endTime']}",
                  style: GoogleFonts.nunito(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                trailing: IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Colors.redAccent,
                  ),
                  onPressed: () {
                    // Cancel Notification
                    if (cls['notificationId'] != null) {
                      NotificationService().cancelNotification(
                        cls['notificationId'],
                      );
                    }
                    // Delete from DB
                    if (cls['id'] != null) {
                      FirebaseDatabase.instance
                          .ref('users/$userId/timetable/$day/${cls['id']}')
                          .remove();
                    }
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }
}
