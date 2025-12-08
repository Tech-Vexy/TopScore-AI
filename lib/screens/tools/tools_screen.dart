import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
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
          // On web, we get bytes
          final bytes = result.files.first.bytes;
          if (bytes != null) {
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
          // On mobile/desktop, we get path
          final path = result.files.single.path;
          if (path != null) {
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error opening PDF: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          "Student Tools",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          children: [
            _buildToolCard(
              context,
              title: "PDF Reader",
              icon: Icons.picture_as_pdf_rounded,
              color: AppColors.googleRed,
              onTap: () => _pickAndOpenPdf(context),
              theme: theme,
            ),
            _buildToolCard(
              context,
              title: "Smart Scanner",
              icon: Icons.center_focus_strong_rounded,
              color: AppColors.googleYellow,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SmartScannerScreen(),
                  ),
                );
              },
              theme: theme,
            ),
            _buildToolCard(
              context,
              title: "Calculator",
              icon: Icons.calculate_rounded,
              color: AppColors.googleBlue,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CalculatorScreen(),
                  ),
                );
              },
              theme: theme,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildToolCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required ThemeData theme,
  }) {
    return Card(
      elevation: 2,
      color: theme.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 32, color: color),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
