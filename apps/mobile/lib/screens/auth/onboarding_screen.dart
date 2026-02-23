import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../services/offline_service.dart';
import '../../constants/colors.dart';
import '../../config/app_theme.dart';

/// 3-step onboarding walkthrough shown to first-time users after role selection.
/// Completion is stored in OfflineService so it only shows once.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  final List<_OnboardingPage> _pages = const [
    _OnboardingPage(
      imagePath: 'assets/images/onboarding_ai_tutor.png',
      title: 'Meet Your AI Tutor',
      subtitle:
          'Ask any question. Get step-by-step explanations in Maths, Science, English, and more — available 24/7.',
    ),
    _OnboardingPage(
      imagePath: 'assets/images/onboarding_digital_library.png',
      title: 'Access Your Resources',
      subtitle:
          'All your CBC and 8-4-4 study materials, past papers, and notes — organised by subject and grade.',
    ),
    _OnboardingPage(
      imagePath: 'assets/images/onboarding_smart_tools.png',
      title: 'Smart Study Tools',
      subtitle:
          'Smart Scanner, Flashcards, Calculator, and more — everything you need to excel in one app.',
    ),
  ];

  void _next() {
    if (_currentPage < _pages.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutQuart,
      );
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    await OfflineService().setStringList('onboarding_complete', ['true']);
    if (mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemCount: _pages.length,
            itemBuilder: (context, i) => _buildPage(_pages[i]),
          ),
          // Skip button
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            right: 20,
            child: TextButton(
              onPressed: _finish,
              child: Text(
                'Skip',
                style: GoogleFonts.nunito(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
            ),
          ),
          // Bottom controls
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Column(
              children: [
                // Dots
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _pages.length,
                    (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: _currentPage == i ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.white
                            .withValues(alpha: _currentPage == i ? 1 : 0.4),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: ElevatedButton(
                    onPressed: _next,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.edupoaBlue,
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      elevation: 4,
                      shadowColor: Colors.black.withValues(alpha: 0.2),
                    ),
                    child: Text(
                      _currentPage == _pages.length - 1
                          ? "Get Started"
                          : 'Next',
                      style: GoogleFonts.nunito(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(_OnboardingPage page) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
      ),
      child: Stack(
        children: [
          // Background Decorative circles
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const Spacer(flex: 2),
                  // Image Asset
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.8, end: 1.0),
                    duration: const Duration(seconds: 2),
                    curve: Curves.easeInOut,
                    builder: (context, value, child) {
                      return Transform.scale(
                        scale: value,
                        child: child,
                      );
                    },
                    child: Image.asset(
                      page.imagePath,
                      height: MediaQuery.of(context).size.height * 0.35,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Glassmorphism Card
                  AppTheme.buildGlassContainer(
                    context,
                    padding: const EdgeInsets.all(24),
                    borderRadius: 24,
                    opacity: 0.1,
                    child: Column(
                      children: [
                        Text(
                          page.title,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.nunito(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          page.subtitle,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.nunito(
                            fontSize: 16,
                            color: Colors.white.withValues(alpha: 0.9),
                            height: 1.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(flex: 4),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingPage {
  final String imagePath;
  final String title;
  final String subtitle;

  const _OnboardingPage({
    required this.imagePath,
    required this.title,
    required this.subtitle,
  });
}
