import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/resources_provider.dart';
import '../providers/ai_tutor_history_provider.dart';
import '../models/firebase_file.dart';
import '../config/app_theme.dart';
import 'bounce_wrapper.dart';

class SessionHistoryCarousel extends StatelessWidget {
  const SessionHistoryCarousel({super.key});

  @override
  Widget build(BuildContext context) {
    final resourcesProvider = Provider.of<ResourcesProvider>(context);
    final aiTutorProvider = Provider.of<AiTutorHistoryProvider>(context);

    final recentFiles = resourcesProvider.recentlyOpened;
    final recentChats = aiTutorProvider.threads;

    // Combine and sort by recency
    final List<dynamic> combinedItems = [];
    combinedItems.addAll(recentFiles);
    combinedItems.addAll(recentChats);

    combinedItems.sort((a, b) {
      DateTime timeA = _getTime(a);
      DateTime timeB = _getTime(b);
      return timeB.compareTo(timeA); // Descending
    });

    final displayItems = combinedItems.take(5).toList();
    final bool useMocks = displayItems.isEmpty;
    final int itemCount = useMocks ? 3 : displayItems.length;

    if (itemCount == 0) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(
            "Jump Back In",
            style: GoogleFonts.nunito(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
        SizedBox(
          height: 140,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: itemCount,
            itemBuilder: (context, index) {
              if (useMocks) {
                return _buildMockSessionCard(context, index);
              } else {
                final item = displayItems[index];
                if (item is FirebaseFile) {
                  return _buildRealSessionCard(context, item);
                } else {
                  return _buildChatSessionCard(context, item);
                }
              }
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  DateTime _getTime(dynamic item) {
    if (item is FirebaseFile) {
      return item.uploadedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    } else if (item is Map<String, dynamic>) {
      final updatedAt = item['updated_at'];
      if (updatedAt is Timestamp) {
        return updatedAt.toDate();
      } else if (updatedAt is int) {
        return DateTime.fromMillisecondsSinceEpoch(updatedAt);
      } else if (updatedAt is String) {
        return DateTime.tryParse(updatedAt) ??
            DateTime.fromMillisecondsSinceEpoch(0);
      }
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  Widget _buildChatSessionCard(
      BuildContext context, Map<String, dynamic> chat) {
    final theme = Theme.of(context);
    const color = Colors.teal;
    const icon = Icons.chat_bubble_outline;

    return BounceWrapper(
      onTap: () {
        context.push('/chat', extra: {
          'thread_id': chat['thread_id'],
          'title': chat['title'],
        });
      },
      child: Container(
        width: 160,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        child: AppTheme.buildGlassContainer(
          context,
          borderRadius: 16,
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(icon, color: color, size: 20),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    chat['title'] ?? 'AI Tutor Chat',
                    style: GoogleFonts.nunito(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: theme.colorScheme.onSurface,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'AI Tutor Session',
                    style: GoogleFonts.nunito(
                      fontSize: 11,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRealSessionCard(BuildContext context, dynamic file) {
    final theme = Theme.of(context);

    // Determine icon based on type
    IconData icon = Icons.description;
    Color color = Colors.blue;
    if (file.type == 'pdf') {
      icon = Icons.picture_as_pdf;
      color = Colors.red;
    } else if (file.type == 'video' || file.type == 'mp4') {
      icon = Icons.play_circle_fill;
      color = Colors.purple;
    } else if (file.type == 'audio' || file.type == 'mp3') {
      icon = Icons.audiotrack;
      color = Colors.orange;
    }

    return BounceWrapper(
      onTap: () {
        if (file.downloadUrl != null) {
          context.push('/pdf-viewer', extra: {
            'url': file.downloadUrl,
            'title': file.displayName,
          });
        }
      },
      child: Container(
        width: 160,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        child: AppTheme.buildGlassContainer(
          context,
          borderRadius: 16,
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    file.name ?? 'Unknown File',
                    style: GoogleFonts.nunito(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: theme.colorScheme.onSurface,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    file.subject ?? 'Resource',
                    style: GoogleFonts.nunito(
                      fontSize: 11,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMockSessionCard(BuildContext context, int index) {
    final theme = Theme.of(context);

    final topics = ["Algebra II", "Photosynthesis", "Kenyan History"];
    final dates = ["2 mins ago", "Yesterday", "2 days ago"];
    final icons = [Icons.calculate, Icons.eco, Icons.history_edu];
    final colors = [Colors.blue, Colors.green, Colors.orange];

    return Container(
      width: 160,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      child: AppTheme.buildGlassContainer(
        context,
        borderRadius: 16,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colors[index].withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icons[index], color: colors[index], size: 20),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  topics[index],
                  style: GoogleFonts.nunito(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: theme.colorScheme.onSurface,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  dates[index],
                  style: GoogleFonts.nunito(
                    fontSize: 11,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
