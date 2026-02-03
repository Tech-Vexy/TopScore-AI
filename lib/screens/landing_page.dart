import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../services/notification_service.dart';
import 'dart:async';
import 'package:flutter/services.dart'; // For Haptics
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'dart:ui' as ui;
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
  Timer? _autoScrollTimer;

  // --- CONTENT DATA ---
  final List<OnboardingContent> _pages = [
    OnboardingContent(
      title: "TopScore AI",
      subtitle: "Your Personal AI Tutor.\nLearn Smarter, Not Harder.",
      imagePath: "assets/images/onboarding_ai_tutor.png",
      icon: FontAwesomeIcons.graduationCap,
      color: AppColors.accentTeal,
    ),
    OnboardingContent(
      title: "Instant Answers",
      subtitle:
          "Stuck on a problem? Snap a photo. Our AI explains concepts in seconds.",
      imagePath: "assets/images/onboarding_snap_solve.png",
      icon: FontAwesomeIcons.bolt,
      color: Colors.amber,
    ),
    OnboardingContent(
      title: "Curated Library",
      subtitle:
          "Access thousands of past papers, notes, and quizzes tailored to your syllabus.",
      imagePath: "assets/images/onboarding_digital_library.png",
      icon: FontAwesomeIcons.bookOpenReader,
      color: const Color(0xFF6C63FF),
    ),
    OnboardingContent(
      title: "Smart Tools",
      subtitle:
          "From scientific calculators to study schedulers, we have what you need.",
      imagePath: "assets/images/onboarding_smart_tools.png",
      icon: FontAwesomeIcons.screwdriverWrench,
      color: const Color(0xFFFF6B6B),
    ),
    OnboardingContent(
      title: "Ready to Excel?",
      subtitle: "Join thousands of students achieving their goals today.",
      imagePath: "assets/images/onboarding_success.png",
      icon: FontAwesomeIcons.rocket,
      color: const Color(0xFF4ECDC4),
      isLast: true,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _startAutoScroll();
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoScroll() {
    _autoScrollTimer?.cancel();
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_currentPage < _pages.length - 1) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 1000),
          curve: Curves.easeInOutCubic,
        );
      } else {
        _pageController.animateToPage(
          0,
          duration: const Duration(milliseconds: 1500),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  void _onUserInteraction() {
    // Reset timer when user interacts
    _startAutoScroll();
  }

  void _nextPage() {
    _onUserInteraction();
    HapticFeedback.lightImpact();
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 600),
        curve: Curves.fastEaseInToSlowEaseOut,
      );
    } else {
      _finishOnboarding();
    }
  }

  void _finishOnboarding() {
    _autoScrollTimer?.cancel();
    HapticFeedback.mediumImpact();
    _goToAuth(); // checking user request: show login page to let them choose
    // context.read<AuthProvider>().continueAsGuest();
  }

  Future<void> _goToAuth() async {
    _onUserInteraction();
    HapticFeedback.selectionClick();

    // Request permissions proactively on mobile before auth flow
    if (!kIsWeb) {
      // Don't await this so it doesn't block navigation
      NotificationService().requestPermissions();
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AuthScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // 1. IMMERSIVE BACKGROUND IMAGES with Parallax-like effect
          Positioned.fill(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) => setState(() => _currentPage = index),
              itemCount: _pages.length,
              itemBuilder: (context, index) {
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    // The main image
                    Hero(
                      tag: 'bg_$index',
                      child: Image.asset(
                        _pages[index].imagePath ?? '',
                        fit: BoxFit.cover,
                        alignment: Alignment.center,
                      ),
                    ),
                    // Dark Overlay for readability
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.3),
                            Colors.black.withValues(alpha: 0.1),
                            Colors.black.withValues(alpha: 0.6),
                            Colors.black.withValues(alpha: 0.9),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          // 2. CONTENT OVERLAY
          SafeArea(
            child: Column(
              children: [
                // Top Bar (Skip / Login)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Smooth Page Indicator
                      Row(
                        children: List.generate(_pages.length, (index) {
                          return _buildPageIndicator(
                            index == _currentPage,
                            _pages[index].color,
                            true,
                          );
                        }),
                      ),
                      // Login Button
                      TextButton(
                        onPressed: _goToAuth,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.white.withValues(alpha: 0.1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: Text(
                          'Log In',
                          style: GoogleFonts.nunito(
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Text Content with Glassmorphic Box
                _buildContentCard(_pages[_currentPage], size),

                // Bottom Navigation (Morphing Button)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 48),
                  child: _MorphingNavButton(
                    isLastPage: _pages[_currentPage].isLast,
                    color: _pages[_currentPage].color,
                    onTap: _nextPage,
                    isDark: isDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentCard(OnboardingContent content, Size size) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  content.title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: size.width > 600 ? 42 : 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  content.subtitle,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.nunito(
                    fontSize: size.width > 600 ? 22 : 18,
                    color: Colors.white.withValues(alpha: 0.8),
                    height: 1.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPageIndicator(bool isActive, Color color, bool isDark) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(right: 6),
      height: 6,
      width: isActive ? 24 : 6,
      decoration: BoxDecoration(
        color: isActive ? color : (isDark ? Colors.white24 : Colors.black12),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}

// --- MORPHING NAVIGATION BUTTON ---

class _MorphingNavButton extends StatelessWidget {
  final bool isLastPage;
  final Color color;
  final VoidCallback onTap;
  final bool isDark;

  const _MorphingNavButton({
    required this.isLastPage,
    required this.color,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutBack,
        height: 60,
        width: isLastPage ? 240 : 60, // Morph width
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.4),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Center Content
            Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, animation) {
                  return FadeTransition(opacity: animation, child: child);
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
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.white,
                          ),
                        ],
                      )
                    : const Icon(
                        Icons.arrow_forward_rounded,
                        key: ValueKey('icon'),
                        color: Colors.white,
                        size: 28,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- ANIMATED BACKGROUND ORB ---

class _AnimatedOrb extends StatefulWidget {
  final Color color;
  const _AnimatedOrb({required this.color});

  @override
  State<_AnimatedOrb> createState() => _AnimatedOrbState();
}

class _AnimatedOrbState extends State<_AnimatedOrb>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: 1.0 + (_controller.value * 0.2), // Breathe effect
          child: ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: 60, sigmaY: 60),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color,
              ),
            ),
          ),
        );
      },
    );
  }
}

// --- DATA MODEL ---

class OnboardingContent {
  final String title;
  final String subtitle;
  final String? imagePath;
  final IconData icon;
  final Color color;
  final bool isLast;

  OnboardingContent({
    required this.title,
    required this.subtitle,
    this.imagePath,
    required this.icon,
    required this.color,
    this.isLast = false,
  });
}
