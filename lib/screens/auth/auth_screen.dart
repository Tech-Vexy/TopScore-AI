import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'login_screen.dart';
import 'signup_screen.dart';

class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LoginScreen(
      onToggle: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          builder: (context) => const _RoleSelectionSheet(),
        );
      },
    );
  }
}

class _RoleSelectionSheet extends StatelessWidget {
  const _RoleSelectionSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            "Join TopScore AI",
            style: GoogleFonts.nunito(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            "Choose your account type to get started",
            style: GoogleFonts.nunito(
              fontSize: 14,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          _buildRoleCard(
            context,
            title: "Student",
            description: "Access library, AI tutor & tools",
            icon: FontAwesomeIcons.userGraduate,
            color: const Color(0xFF6C63FF),
            onTap: () => _navigateToSignup(context, 'student'),
          ),
          const SizedBox(height: 12),
          _buildRoleCard(
            context,
            title: "Teacher",
            description: "Manage classes & resources",
            icon: FontAwesomeIcons.chalkboardUser,
            color: const Color(0xFFE91E63),
            onTap: () => _navigateToSignup(context, 'teacher'),
          ),
          const SizedBox(height: 12),
          _buildRoleCard(
            context,
            title: "Parent",
            description: "Monitor progress & subscription",
            icon: FontAwesomeIcons.userGroup,
            color: const Color(0xFF4ECDC4),
            onTap: () => _navigateToSignup(context, 'parent'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildRoleCard(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.05),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: FaIcon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.nunito(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    description,
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToSignup(BuildContext context, String role) {
    Navigator.pop(context); // Close bottom sheet
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => SignupScreen(role: role)),
    );
  }
}
