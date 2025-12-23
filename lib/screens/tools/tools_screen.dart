import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../constants/colors.dart';
import 'pdf_viewer_screen.dart';
import 'smart_scanner_screen.dart';
import 'calculator_screen.dart';

class ToolsScreen extends StatelessWidget {
  const ToolsScreen({super.key});

  Future<void> _pickAndOpenPdf(BuildContext context) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null) {
        if (kIsWeb) {
          final bytes = result.files.first.bytes;
          if (bytes != null && context.mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PdfViewerScreen(
                  bytes: bytes,
                  title: result.files.first.name,
                ),
              ),
            );
          }
        } else {
          final path = result.files.single.path;
          if (path != null && context.mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PdfViewerScreen(
                  file: File(path),
                  title: result.files.first.name,
                ),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening PDF: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: FaIcon(
            FontAwesomeIcons.arrowLeft,
            size: 18,
            color: isDark ? AppColors.textDark : AppColors.text,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.cardPurple.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const FaIcon(
                FontAwesomeIcons.toolbox,
                size: 16,
                color: AppColors.cardPurple,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'Smart Tools',
              style: GoogleFonts.roboto(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: isDark ? AppColors.textDark : AppColors.text,
              ),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Header Section
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryPurple.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                const FaIcon(
                  FontAwesomeIcons.screwdriverWrench,
                  size: 36,
                  color: AppColors.accentTeal,
                ),
                const SizedBox(height: 16),
                Text(
                  "Productivity Tools",
                  style: GoogleFonts.roboto(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Essential tools to boost your study efficiency",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.roboto(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          Text(
            "Available Tools",
            style: GoogleFonts.roboto(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.textDark : AppColors.text,
            ),
          ),

          const SizedBox(height: 16),

          // Tools Grid
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 0.95,
            children: [
              _buildToolCard(
                context,
                title: "PDF Reader",
                description: "Open and read PDF documents",
                icon: FontAwesomeIcons.filePdf,
                color: AppColors.cardPink,
                onTap: () => _pickAndOpenPdf(context),
                isDark: isDark,
              ),
              _buildToolCard(
                context,
                title: "Smart Scanner",
                description: "Scan documents with AI",
                icon: FontAwesomeIcons.cameraRetro,
                color: AppColors.cardOrange,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SmartScannerScreen(),
                    ),
                  );
                },
                isDark: isDark,
              ),
              _buildToolCard(
                context,
                title: "Calculator",
                description: "Scientific calculator",
                icon: FontAwesomeIcons.calculator,
                color: AppColors.cardBlue,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CalculatorScreen(),
                    ),
                  );
                },
                isDark: isDark,
              ),
              _buildToolCard(
                context,
                title: "More Coming",
                description: "Stay tuned!",
                icon: FontAwesomeIcons.wandMagicSparkles,
                color: AppColors.cardTeal,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'More tools coming soon!',
                        style: GoogleFonts.roboto(),
                      ),
                      backgroundColor: AppColors.accentTeal,
                    ),
                  );
                },
                isDark: isDark,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToolCard(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceElevatedDark : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.15),
              blurRadius: 15,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.03),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: FaIcon(icon, size: 28, color: color),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: GoogleFonts.roboto(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: isDark ? AppColors.textDark : AppColors.text,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: GoogleFonts.roboto(
                fontSize: 12,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
