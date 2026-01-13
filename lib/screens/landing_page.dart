import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'dart:ui' as ui; // Needed for ImageFilter
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

  // --- CONTENT DATA ---
  final List<OnboardingContent> _pages = [
    OnboardingContent(
      title: "TopScore AI",
      subtitle: "Your Personal AI Tutor.\nLearn Smarter, Not Harder.",
      icon: FontAwesomeIcons.graduationCap,
      color: AppColors.accentTeal,
      isWelcome: true,
    ),
    OnboardingContent(
      title: "Instant Answers",
      subtitle:
          "Stuck on a problem? Snap a photo or type it in. Our AI explains concepts in seconds.",
      icon: FontAwesomeIcons.bolt,
      color: Colors.amber,
    ),
    OnboardingContent(
      title: "Curated Library",
      subtitle:
          "Access thousands of past papers, notes, and quizzes tailored to your syllabus.",
      icon: FontAwesomeIcons.bookOpenReader,
      color: const Color(0xFF6C63FF),
    ),
    OnboardingContent(
      title: "Smart Tools",
      subtitle:
          "From scientific calculators to study schedulers, we have the tools you need to excel.",
      icon: FontAwesomeIcons.screwdriverWrench,
      color: const Color(0xFFFF6B6B),
    ),
    OnboardingContent(
      title: "Ready to Excel?",
      subtitle: "Join thousands of students achieving their goals today.",
      icon: FontAwesomeIcons.rocket,
      color: const Color(0xFF4ECDC4),
      isLast: true,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToNextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 600),
        curve: Curves.fastEaseInToSlowEaseOut,
      );
    } else {
      _goToAuthScreen(isLogin: false);
    }
  }

  void _goToAuthScreen({bool isLogin = true}) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AuthScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Theme determination
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColors = isDark
        ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
        : [const Color(0xFFF8FAFC), const Color(0xFFE2E8F0)];

    return Scaffold(
      body: Stack(
        children: [
          // 1. BACKGROUND LAYER (Animated Orbs)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: bgColors,
                ),
              ),
            ),
          ),
          // Ambient Orb 1 (Top Left)
          Positioned(
            top: -100,
            left: -100,
            child: _AnimatedOrb(
              color: _pages[_currentPage].color.withValues(alpha: 0.3),
            ),
          ),
          // Ambient Orb 2 (Bottom Right)
          Positioned(
            bottom: -50,
            right: -50,
            child: _AnimatedOrb(
              color: AppColors.primaryPurple.withValues(alpha: 0.2),
            ),
          ),

          // 2. CONTENT LAYER
          SafeArea(
            child: Column(
              children: [
                // --- TOP BAR (Skip Button) ---
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (_currentPage < _pages.length - 1)
                        TextButton(
                          onPressed: () => _goToAuthScreen(isLogin: true),
                          style: TextButton.styleFrom(
                            foregroundColor: isDark
                                ? Colors.white70
                                : Colors.black54,
                          ),
                          child: Text(
                            'Skip',
                            style: GoogleFonts.nunito(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // --- PAGE VIEW ---
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (index) =>
                        setState(() => _currentPage = index),
                    itemCount: _pages.length,
                    itemBuilder: (context, index) {
                      return _OnboardingPage(
                        content: _pages[index],
                        isDark: isDark,
                      );
                    },
                  ),
                ),

                // --- BOTTOM NAVIGATION AREA ---
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Page Indicators (Dots)
                      Row(
                        children: List.generate(_pages.length, (index) {
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.only(right: 6),
                            height: 6,
                            width: _currentPage == index ? 24 : 6,
                            decoration: BoxDecoration(
                              color: _currentPage == index
                                  ? _pages[_currentPage].color
                                  : (isDark ? Colors.white24 : Colors.black12),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          );
                        }),
                      ),

                      // Circular Progress Button
                      _CircularNavButton(
                        progress: (_currentPage + 1) / _pages.length,
                        color: _pages[_currentPage].color,
                        isLastPage: _currentPage == _pages.length - 1,
                        onTap: _goToNextPage,
                        isDark: isDark,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --- WIDGETS ---

class _OnboardingPage extends StatelessWidget {
  final OnboardingContent content;
  final bool isDark;

  const _OnboardingPage({required this.content, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon Container with clean shadow
          TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 600),
            tween: Tween(begin: 0.0, end: 1.0),
            curve: Curves.elasticOut,
            builder: (context, val, child) {
              return Transform.scale(scale: val, child: child);
            },
            child: Container(
              height: 100,
              width: 100,
              decoration: BoxDecoration(
                color: content.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: content.color.withValues(alpha: 0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Center(
                child: FaIcon(content.icon, size: 40, color: content.color),
              ),
            ),
          ),
          const SizedBox(height: 48),

          // Title
          Text(
            content.title,
            style: GoogleFonts.nunito(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : const Color(0xFF1E293B),
              height: 1.1,
            ),
          ),
          const SizedBox(height: 16),

          // Subtitle
          Text(
            content.subtitle,
            style: GoogleFonts.nunito(
              fontSize: 18,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _CircularNavButton extends StatelessWidget {
  final double progress;
  final Color color;
  final bool isLastPage;
  final VoidCallback onTap;
  final bool isDark;

  const _CircularNavButton({
    required this.progress,
    required this.color,
    required this.isLastPage,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 70,
        height: 70,
        child: Stack(
          children: [
            // Progress Indicator
            Center(
              child: SizedBox(
                width: 70,
                height: 70,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  backgroundColor: isDark ? Colors.white10 : Colors.black12,
                ),
              ),
            ),
            // Button Center
            Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: FaIcon(
                    isLastPage
                        ? FontAwesomeIcons.check
                        : FontAwesomeIcons.arrowRight,
                    size: 20,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
            imageFilter: ui.ImageFilter.blur(sigmaX: 80, sigmaY: 80),
            child: Container(
              width: 300,
              height: 300,
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
  final IconData icon;
  final Color color;
  final bool isWelcome;
  final bool isLast;

  OnboardingContent({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.isWelcome = false,
    this.isLast = false,
  });
}
