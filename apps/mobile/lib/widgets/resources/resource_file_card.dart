import 'package:flutter/material.dart';
import '../../models/firebase_file.dart';
import '../../config/app_theme.dart';
import '../../constants/colors.dart';
import 'package:google_fonts/google_fonts.dart';

class ResourceFileCard extends StatelessWidget {
  final FirebaseFile file;
  final VoidCallback onTap;

  const ResourceFileCard({
    super.key,
    required this.file,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sizeStr = file.size != null
        ? '${(file.size! / (1024 * 1024)).toStringAsFixed(2)} MB'
        : 'Unknown size';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppColors.border, width: 1),
        ),
        child: Row(
          children: [
            _buildIcon(),
            const SizedBox(width: AppTheme.spacingMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    file.displayName,
                    style: GoogleFonts.nunito(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: theme.colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        '${file.subject ?? 'General'} • ${file.gradeLabel}',
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        sizeStr,
                        style: GoogleFonts.nunito(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppTheme.spacingSm),
            const Icon(
              Icons.chevron_right,
              color: AppColors.textSecondary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon() {
    IconData iconData = Icons.insert_drive_file;
    Color iconColor = AppColors.primary;

    if (file.type == 'pdf') {
      iconData = Icons.picture_as_pdf;
      iconColor = Colors.redAccent;
    } else if (file.type == 'jpg' || file.type == 'png') {
      iconData = Icons.image;
      iconColor = Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(iconData, color: iconColor, size: 24),
    );
  }
}
