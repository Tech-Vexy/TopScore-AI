import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:file_picker/file_picker.dart';
import '../../constants/colors.dart';
import '../../providers/auth_provider.dart';
import '../../services/firebase_storage_service.dart';

class TeacherHomeScreen extends StatefulWidget {
  const TeacherHomeScreen({super.key});

  @override
  State<TeacherHomeScreen> createState() => _TeacherHomeScreenState();
}

class _TeacherHomeScreenState extends State<TeacherHomeScreen> {
  final FirebaseStorageService _storageService = FirebaseStorageService();
  bool _isUploading = false;

  Future<void> _uploadResource() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'ppt', 'pptx'],
        withData: true,
      );

      if (result != null && result.files.single.bytes != null) {
        if (!mounted) return;
        // Collect Metadata (Mocked for MVP until UI inputs are added)
        // In a real app, show a Dialog here to get title, subject, grade
        String title = result.files.single.name;
        String subject = "General"; // Default
        int grade = 0; // Default

        setState(() => _isUploading = true);

        final user = Provider.of<AuthProvider>(
          context,
          listen: false,
        ).userModel;
        final file = result.files.single;

        final downloadUrl = await _storageService.uploadResource(
          fileBytes: file.bytes!,
          fileName: file.name,
          contentType: 'application/pdf',
          title: title,
          subject: subject,
          grade: grade,
          teacherId: user?.uid ?? 'unknown',
        );

        if (downloadUrl != null && mounted) {
          _showSnackBar(
            'Resource uploaded & queued for processing!',
            AppColors.googleGreen,
          );
        } else if (mounted) {
          _showSnackBar('Failed to upload resource.', AppColors.error);
        }
      }
    } catch (e) {
      debugPrint('Error picking/uploading file: $e');
      if (mounted) _showSnackBar('Error: $e', AppColors.error);
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).userModel;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
        title: Text(
          "Teacher Dashboard",
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () =>
                  Provider.of<AuthProvider>(context, listen: false).signOut(),
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.accentTeal, AppColors.edupoaTeal],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accentTeal.withValues(alpha: 0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white,
                    child: Text(
                      user?.displayName.substring(0, 1).toUpperCase() ?? "T",
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.accentTeal,
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Welcome back,",
                          style: GoogleFonts.poppins(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          user?.displayName ?? "Teacher",
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Quick Actions
            Text(
              "Quick Actions",
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildActionCard(
                    icon: FontAwesomeIcons.upload,
                    title: "Upload Resource",
                    color: AppColors.primaryPurple,
                    onTap: _uploadResource,
                    isLoading: _isUploading,
                    theme: theme,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildActionCard(
                    icon: FontAwesomeIcons.listCheck,
                    title: "Class Activities",
                    color: AppColors.accentTeal,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Coming Soon!')),
                      );
                    },
                    theme: theme,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Recent Activities (Placeholder)
            Text(
              "Recent Activities",
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            _buildPlaceholderActivity(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
    required ThemeData theme,
    bool isLoading = false,
  }) {
    return InkWell(
      onTap: isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            if (isLoading)
              const SizedBox(
                height: 40,
                width: 40,
                child: CircularProgressIndicator(strokeWidth: 3),
              )
            else
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: FaIcon(icon, color: color, size: 24),
              ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderActivity(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const FaIcon(
                FontAwesomeIcons.filePdf,
                color: Colors.blue,
                size: 16,
              ),
            ),
            title: Text(
              "Math_Assignment_1.pdf",
              style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              "Uploaded 2 hours ago",
              style: GoogleFonts.poppins(fontSize: 12),
            ),
          ),
          Divider(color: theme.dividerColor),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const FaIcon(
                FontAwesomeIcons.check,
                color: Colors.green,
                size: 16,
              ),
            ),
            title: Text(
              "Class 5B Attendance",
              style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              "Marked just now",
              style: GoogleFonts.poppins(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
