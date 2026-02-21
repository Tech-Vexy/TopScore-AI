import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/colors.dart';
import '../config/app_theme.dart';
import '../widgets/bounce_wrapper.dart';
import 'auth/auth_screen.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage>
    with TickerProviderStateMixin {
  late PageController _pageController;
  late Timer _autoScrollTimer;
  int _currentPage = 0;
  static const Duration _autoScrollDuration = Duration(seconds: 4);

  // --- CONTENT DATA ---
  final List<OnboardingContent> _pages = [
    OnboardingContent(
      title: "TopScore AI",
      subtitle: "Your Personal AI Tutor.\nLearn Smarter, Not Harder.",
      imagePath: "assets/images/logo.png",
      color: AppColors.accentTeal,
    ),
    OnboardingContent(
      title: "Instant Answers",
      subtitle:
          "Stuck on a problem? Snap a photo. Our AI explains concepts in seconds.",
      imagePath: "assets/images/onboarding_snap_solve.png",
      color: Colors.amber,
    ),
    OnboardingContent(
      title: "AI Tutor",
      subtitle:
          "Get personalized explanations and step-by-step guidance from your AI tutor.",
      imagePath: "assets/images/onboarding_ai_tutor.png",
      color: const Color(0xFF6C63FF),
    ),
    OnboardingContent(
      title: "Digital Library",
      subtitle:
          "Access thousands of past papers, notes, and quizzes tailored to your syllabus.",
      imagePath: "assets/images/onboarding_digital_library.png",
      color: const Color(0xFFFF6B6B),
    ),
    OnboardingContent(
      title: "Smart Tools",
      subtitle:
          "From scientific calculators to study schedulers, we have what you need.",
      imagePath: "assets/images/onboarding_smart_tools.png",
      color: const Color(0xFF4ECDC4),
    ),
    OnboardingContent(
      title: "Ready to Excel?",
      subtitle: "Join thousands of students achieving their goals today.",
      imagePath: "assets/images/onboarding_success.png",
      color: AppColors.primaryPurple,
      isLast: true,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _startAutoScroll();
  }

  void _startAutoScroll() {
    _autoScrollTimer = Timer.periodic(_autoScrollDuration, (timer) {
      if (_currentPage < _pages.length - 1) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOut,
        );
      } else {
        _pageController.animateToPage(
          0,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _stopAutoScroll() {
    _autoScrollTimer.cancel();
  }

  @override
  void dispose() {
    _autoScrollTimer.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    HapticFeedback.lightImpact();
    _stopAutoScroll();
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: AppTheme.durationSlow,
        curve: Curves.fastEaseInToSlowEaseOut,
      );
      _startAutoScroll();
    } else {
      _finishOnboarding();
    }
  }

  void _finishOnboarding() {
    HapticFeedback.mediumImpact();
    _goToAuth();
  }

  void _goToAuth() {
    HapticFeedback.selectionClick();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AuthScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Fullscreen PageView
          PageView.builder(
            controller: _pageController,
            physics: const BouncingScrollPhysics(),
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemCount: _pages.length,
            itemBuilder: (context, index) {
              return _buildFullscreenImage(_pages[index]);
            },
          ),

          // Top overlay with indicators and login button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingLg,
                vertical: AppTheme.spacingMd,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Page Indicators
                  Semantics(
                    label: 'Page ${_currentPage + 1} of ${_pages.length}',
                    child: Row(
                      children: List.generate(_pages.length, (index) {
                        return _buildPageIndicator(index == _currentPage);
                      }),
                    ),
                  ),
                  // Login Button
                  if (!_pages[_currentPage].isLast)
                    Semantics(
                      button: true,
                      label: 'Log in to your account',
                      child: BounceWrapper(
                        onTap: _goToAuth,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppTheme.spacingLg,
                            vertical: AppTheme.spacingSm,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.4),
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusFull),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            'Log In',
                            style: GoogleFonts.nunito(
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Bottom button
          Positioned(
            bottom: AppTheme.spacing2xl,
            left: AppTheme.spacingLg,
            right: AppTheme.spacingLg,
            child: SafeArea(
              child: _MorphingNavButton(
                isLastPage: _pages[_currentPage].isLast,
                onTap: _nextPage,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageIndicator(bool isActive) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(right: 6),
      height: 6,
      width: isActive ? 24 : 6,
      decoration: BoxDecoration(
        color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }

  Widget _buildFullscreenImage(OnboardingContent content) {
    return Semantics(
      label: '${content.title}: ${content.subtitle}',
      child: GestureDetector(
        onTap: () {
          _stopAutoScroll();
          _startAutoScroll();
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Fullscreen Image
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 600),
              child: Image.asset(
                content.imagePath,
                key: ValueKey(content.imagePath),
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: Colors.black,
                  child: const Center(
                    child: Icon(
                      Icons.image_outlined,
                      size: 100,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),

            // Gradient overlay for text readability
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.7),
                      Colors.black.withValues(alpha: 0.9),
                    ],
                    stops: const [0.0, 0.4, 0.7, 1.0],
                  ),
                ),
              ),
            ),

            // Text content at bottom
            Positioned(
              bottom: 120,
              left: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Title
                    Text(
                      content.title,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        height: 1.1,
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            offset: const Offset(0, 2),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Subtitle
                    Text(
                      content.subtitle,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.nunito(
                        fontSize: 18,
                        color: Colors.white.withValues(alpha: 0.95),
                        height: 1.5,
                        fontWeight: FontWeight.w500,
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            offset: const Offset(0, 1),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- MORPHING NAVIGATION BUTTON ---

class _MorphingNavButton extends StatelessWidget {
  final bool isLastPage;
  final VoidCallback onTap;

  const _MorphingNavButton({
    required this.isLastPage,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: isLastPage ? 'Get started with TopScore AI' : 'Next page',
      child: BounceWrapper(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOutBack,
          height: 64,
          width: isLastPage ? 260 : 64,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.radiusFull),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Center(
            child: AnimatedSwitcher(
              duration: AppTheme.durationNormal,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: animation,
                    child: child,
                  ),
                );
              },
              child: isLastPage
                  ? Row(
                      key: const ValueKey('text'),
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Get Started",
                          style: GoogleFonts.nunito(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(width: AppTheme.spacingSm),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.black,
                          size: 24,
                        ),
                      ],
                    )
                  : const Icon(
                      Icons.arrow_forward_rounded,
                      key: ValueKey('icon'),
                      color: Colors.black,
                      size: 32,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

// --- DATA MODEL ---

class OnboardingContent {
  final String title;
  final String subtitle;
  final String imagePath;
  final Color color;
  final bool isLast;

  OnboardingContent({
    required this.title,
    required this.subtitle,
    required this.imagePath,
    required this.color,
    this.isLast = false,
  });
}
