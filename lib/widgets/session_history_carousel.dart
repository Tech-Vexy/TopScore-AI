import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/app_theme.dart';

class SessionHistoryCarousel extends StatelessWidget {
  const SessionHistoryCarousel({super.key});

  @override
  Widget build(BuildContext context) {
    // In a real implementation, you would fetch this from a provider
    // utilizing the ChatHistoryManager. For now, we'll mock or assume access.
    // Let's assume we want to show a placeholder or fetching state if not connected.

    // For this specific UI component, we'll create a static list of "Recent Sessions"
    // to demonstrate the UI as requested in the plan, since connecting fully to
    // ChatHistoryManager might require a Provider setup we haven't fully inspected yet.
    // However, we should try to be dynamic if possible.

    // Let's implement a UI-first approach that can be easily wired up.

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
            itemCount: 3, // Mock count for now
            itemBuilder: (context, index) {
              return _buildSessionCard(context, index);
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSessionCard(BuildContext context, int index) {
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
