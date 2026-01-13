import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../constants/colors.dart';

class ActivityFeedWidget extends StatelessWidget {
  final List<String> childrenIds;

  const ActivityFeedWidget({super.key, required this.childrenIds});

  @override
  Widget build(BuildContext context) {
    if (childrenIds.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Text(
            "Recent Activity",
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
        const SizedBox(height: 12),
        StreamBuilder<QuerySnapshot>(
          // Query 'activity_logs' where 'userId' is in childrenIds
          // Note: Firestore 'whereIn' limits to 10 items.
          stream: FirebaseFirestore.instance
              .collection('activity_logs')
              .where('userId', whereIn: childrenIds.take(10).toList())
              .orderBy('timestamp', descending: true)
              .limit(5)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).dividerColor.withValues(alpha: 0.1),
                  ),
                ),
                child: Center(
                  child: Text(
                    "No recent activity to show.",
                    style: GoogleFonts.poppins(
                      color: Theme.of(context).disabledColor,
                    ),
                  ),
                ),
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: snapshot.data!.docs.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final data =
                    snapshot.data!.docs[index].data() as Map<String, dynamic>;
                return _buildActivityItem(context, data);
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildActivityItem(BuildContext context, Map<String, dynamic> data) {
    final activityType = data['type'] ?? 'general';
    final title = data['title'] ?? 'Activity';
    final description = data['description'] ?? '';
    final timestamp =
        (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();

    IconData icon;
    Color color;

    switch (activityType) {
      case 'quiz_completed':
        icon = Icons.assignment_turned_in;
        color = AppColors.googleGreen;
        break;
      case 'resource_viewed':
        icon = Icons.menu_book;
        color = AppColors.googleBlue;
        break;
      case 'ai_chat':
        icon = Icons.chat_bubble;
        color = AppColors.secondaryViolet;
        break;
      default:
        icon = Icons.notifications;
        color = AppColors.googleYellow;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                if (description.isNotEmpty)
                  Text(
                    description,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          Text(
            DateFormat('MMM d, h:mm a').format(timestamp),
            style: GoogleFonts.poppins(
              fontSize: 10,
              color: Theme.of(context).disabledColor,
            ),
          ),
        ],
      ),
    );
  }
}
