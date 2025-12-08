import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/colors.dart';
import 'auth/auth_screen.dart';

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              // Logo & Title
              const Icon(Icons.school, size: 64, color: AppColors.primary),
              const SizedBox(height: 16),
              Text(
                'TopScore AI',
                style: GoogleFonts.outfit(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              Text(
                'Your Personal AI Tutor',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
              
              const SizedBox(height: 40),
              
              // Hero Image / Illustration Placeholder
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                height: 200,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.auto_awesome, size: 64, color: AppColors.surface),
                      const SizedBox(height: 16),
                      Text(
                        'Learn Smarter, Not Harder',
                        style: GoogleFonts.outfit(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.surface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // Features Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    _buildFeatureRow(
                      context,
                      icon: Icons.psychology,
                      color: AppColors.googleBlue,
                      title: 'AI Tutor',
                      description: 'Get instant answers and personalized explanations 24/7.',
                    ),
                    const SizedBox(height: 24),
                    _buildFeatureRow(
                      context,
                      icon: Icons.library_books,
                      color: AppColors.googleGreen,
                      title: 'Study Resources',
                      description: 'Access a vast library of notes, past papers, and quizzes.',
                    ),
                    const SizedBox(height: 24),
                    _buildFeatureRow(
                      context,
                      icon: Icons.build,
                      color: AppColors.googleYellow,
                      title: 'Smart Tools',
                      description: 'Use our scanner, calculator, and other tools to boost productivity.',
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // Get Started Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const AuthScreen()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                    ),
                    child: Text(
                      'Get Started',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              TextButton(
                onPressed: () {
                   Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AuthScreen()),
                  );
                },
                child: Text(
                  'Already have an account? Log in',
                  style: GoogleFonts.outfit(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureRow(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String description,
  }) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 28),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
