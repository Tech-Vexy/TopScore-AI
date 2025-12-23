import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../providers/auth_provider.dart';
import '../../constants/colors.dart';
import '../../constants/strings.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final isLoading = authProvider.isLoading;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? AppColors.darkGradient : null,
          color: isDark ? null : AppColors.background,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                _buildHeader(context, isDark),

                const SizedBox(height: 40),

                // Role Cards
                _RoleCard(
                  title: "Student",
                  description:
                      "Access learning materials, AI tutoring, and resources",
                  icon: FontAwesomeIcons.userGraduate,
                  color: AppColors.cardBlue,
                  isDark: isDark,
                  onPressed: isLoading
                      ? null
                      : () => authProvider.completeGoogleSignup('student'),
                ),
                const SizedBox(height: 16),
                _RoleCard(
                  title: "Teacher",
                  description:
                      "Manage classes, share resources, and track students",
                  icon: FontAwesomeIcons.chalkboardUser,
                  color: AppColors.cardPurple,
                  isDark: isDark,
                  onPressed: isLoading
                      ? null
                      : () => authProvider.completeGoogleSignup('teacher'),
                ),
                const SizedBox(height: 16),
                _RoleCard(
                  title: "Parent",
                  description:
                      "Monitor your child's progress and learning journey",
                  icon: FontAwesomeIcons.peopleRoof,
                  color: AppColors.cardGreen,
                  isDark: isDark,
                  onPressed: isLoading
                      ? null
                      : () => authProvider.completeGoogleSignup('parent'),
                ),

                // Loading indicator
                if (isLoading) _buildLoadingIndicator(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: AppColors.heroGradient,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryPurple.withValues(alpha: 0.4),
                blurRadius: 25,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const FaIcon(
            FontAwesomeIcons.userCheck,
            size: 40,
            color: AppColors.accentTeal,
          ),
        ),
        const SizedBox(height: 28),
        Text(
          "Choose Your Role",
          style: GoogleFonts.roboto(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.textDark : AppColors.text,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        Text(
          "Tell us how you'll be using ${AppStrings.appName}",
          style: GoogleFonts.roboto(
            fontSize: 15,
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildLoadingIndicator() {
    return Container(
      margin: const EdgeInsets.only(top: 32),
      child: Column(
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.accentTeal),
            strokeWidth: 3,
          ),
          const SizedBox(height: 16),
          Text(
            "Setting up your account...",
            style: GoogleFonts.roboto(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final bool isDark;
  final VoidCallback? onPressed;

  const _RoleCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.isDark,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceElevatedDark : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.03),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: FaIcon(icon, size: 26, color: color),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.roboto(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.textDark : AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: GoogleFonts.roboto(
                      fontSize: 13,
                      height: 1.4,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: FaIcon(
                FontAwesomeIcons.chevronRight,
                size: 14,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
