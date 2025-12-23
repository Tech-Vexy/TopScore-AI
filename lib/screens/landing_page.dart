import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../constants/colors.dart';
import 'auth/auth_screen.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage>
    with TickerProviderStateMixin {
  late PageController _pageController;
  int _currentPage = 0;

  // Total pages: Welcome + 4 features + CTA
  final int _totalPages = 6;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 1.0, initialPage: 0);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToNextPage() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _goToAuthScreen({bool isLogin = true}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AuthScreen(initialIsLogin: isLogin),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? AppColors.darkGradient : AppColors.heroGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Skip button at top right
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Logo
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const FaIcon(
                            FontAwesomeIcons.graduationCap,
                            size: 18,
                            color: AppColors.accentTeal,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'TopScore AI',
                          style: GoogleFonts.roboto(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    // Skip button
                    if (_currentPage < _totalPages - 1)
                      TextButton(
                        onPressed: () => _goToAuthScreen(isLogin: true),
                        child: Text(
                          'Skip',
                          style: GoogleFonts.roboto(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Main content - PageView
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                    });
                  },
                  children: [
                    // Page 1: Welcome
                    _buildWelcomePage(isDark),

                    // Page 2-5: Features
                    _buildFeaturePage(
                      icon: FontAwesomeIcons.brain,
                      color: AppColors.cardBlue,
                      title: 'AI-Powered Tutor',
                      description:
                          'Get instant, personalized explanations for any topic. Our AI understands your learning style and adapts to help you learn better.',
                      isDark: isDark,
                    ),
                    _buildFeaturePage(
                      icon: FontAwesomeIcons.folderOpen,
                      color: AppColors.cardGreen,
                      title: 'Study Resources',
                      description:
                          'Access a vast library of notes, past papers, and quizzes curated by experts. Everything you need to excel in one place.',
                      isDark: isDark,
                    ),
                    _buildFeaturePage(
                      icon: FontAwesomeIcons.toolbox,
                      color: AppColors.cardPurple,
                      title: 'Smart Tools',
                      description:
                          'Use our document scanner, scientific calculator, and other productivity tools to boost your study efficiency.',
                      isDark: isDark,
                    ),
                    _buildFeaturePage(
                      icon: FontAwesomeIcons.clock,
                      color: AppColors.cardTeal,
                      title: 'Available 24/7',
                      description:
                          'Study anytime, anywhere. Your AI tutor never sleeps and is always ready to help you succeed.',
                      isDark: isDark,
                    ),

                    // Page 6: CTA with Get Started button
                    _buildCTAPage(isDark),
                  ],
                ),
              ),

              // Page indicator and navigation
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // Page indicator dots
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_totalPages, (index) {
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: _currentPage == index ? 28 : 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: _currentPage == index
                                ? AppColors.accentTeal
                                : Colors.white.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(5),
                          ),
                        );
                      }),
                    ),

                    const SizedBox(height: 24),

                    // Navigation button
                    if (_currentPage < _totalPages - 1)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _goToNextPage,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.accentTeal,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Next',
                                style: GoogleFonts.roboto(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const FaIcon(
                                FontAwesomeIcons.arrowRight,
                                size: 16,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomePage(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated logo container
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutBack,
            builder: (context, value, child) {
              return Transform.scale(scale: value, child: child);
            },
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accentTeal.withValues(alpha: 0.3),
                    blurRadius: 40,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: const FaIcon(
                FontAwesomeIcons.graduationCap,
                size: 72,
                color: AppColors.accentTeal,
              ),
            ),
          ),
          const SizedBox(height: 40),

          // Title
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOut,
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, 20 * (1 - value)),
                  child: child,
                ),
              );
            },
            child: Column(
              children: [
                Text(
                  'Welcome to',
                  style: GoogleFonts.roboto(
                    fontSize: 20,
                    fontWeight: FontWeight.w400,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'TopScore AI',
                  style: GoogleFonts.roboto(
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: -1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Subtitle
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOut,
            builder: (context, value, child) {
              return Opacity(opacity: value, child: child);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'Your Personal AI Tutor\nLearn Smarter, Not Harder',
                textAlign: TextAlign.center,
                style: GoogleFonts.roboto(
                  fontSize: 16,
                  height: 1.6,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturePage({
    required IconData icon,
    required Color color,
    required String title,
    required String description,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Feature icon with animated container
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutBack,
            builder: (context, value, child) {
              return Transform.scale(scale: value, child: child);
            },
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: color.withValues(alpha: 0.3),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.2),
                    blurRadius: 40,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: FaIcon(icon, size: 64, color: color),
            ),
          ),
          const SizedBox(height: 48),

          // Feature title
          Text(
            title,
            style: GoogleFonts.roboto(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          // Feature description
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              description,
              style: GoogleFonts.roboto(
                fontSize: 16,
                height: 1.6,
                color: Colors.white.withValues(alpha: 0.85),
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCTAPage(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Rocket icon
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutBack,
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: Transform.translate(
                  offset: Offset(0, -20 * (1 - value)),
                  child: child,
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                gradient: AppColors.accentGradient,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accentTeal.withValues(alpha: 0.4),
                    blurRadius: 40,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: const FaIcon(
                FontAwesomeIcons.rocket,
                size: 64,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 48),

          // CTA Title
          Text(
            'Ready to Excel?',
            style: GoogleFonts.roboto(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          // CTA Description
          Text(
            'Join thousands of students already achieving their academic goals with TopScore AI.',
            style: GoogleFonts.roboto(
              fontSize: 16,
              height: 1.6,
              color: Colors.white.withValues(alpha: 0.85),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),

          // Get Started Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _goToAuthScreen(isLogin: false),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primaryPurple,
                padding: const EdgeInsets.symmetric(vertical: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Get Started Free',
                    style: GoogleFonts.roboto(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const FaIcon(FontAwesomeIcons.arrowRight, size: 16),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Login link
          TextButton(
            onPressed: () => _goToAuthScreen(isLogin: true),
            child: Text(
              'Already have an account? Log in',
              style: GoogleFonts.roboto(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
