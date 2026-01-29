import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For Haptics
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'dart:ui' as ui;
import '../constants/colors.dart';
import '../providers/auth_provider.dart';
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
    ),
    OnboardingContent(
      title: "Instant Answers",
      subtitle:
          "Stuck on a problem? Snap a photo. Our AI explains concepts in seconds.",
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
          "From scientific calculators to study schedulers, we have what you need.",
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

  void _nextPage() {
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
    HapticFeedback.mediumImpact();
    context.read<AuthProvider>().continueAsGuest();
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Dynamic background gradient based on current page color
    final activeColor = _pages[_currentPage].color;
    final bgGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isDark
          ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
          : [const Color(0xFFF8FAFC), const Color(0xFFE2E8F0)],
    );

    return Scaffold(
      body: Stack(
        children: [
          // 1. BACKGROUND
          Positioned.fill(
            child: AnimatedContainer(
              duration: const Duration(seconds: 1),
              decoration: BoxDecoration(gradient: bgGradient),
            ),
          ),

          // Animated Orbs (Background Effects)
          Positioned(
            top: -100,
            left: -50,
            child: _AnimatedOrb(color: activeColor.withValues(alpha: 0.2)),
          ),
          Positioned(
            bottom: -50,
            right: -50,
            child: _AnimatedOrb(color: activeColor.withValues(alpha: 0.15)),
          ),

          // 2. MAIN CONTENT
          SafeArea(
            child: Column(
              children: [
                // Top Bar (Skip / Login)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Smooth Page Indicator
                      Row(
                        children: List.generate(_pages.length, (index) {
                          return _buildPageIndicator(
                              index == _currentPage, activeColor, isDark);
                        }),
                      ),
                      // Login Button
                      if (!_pages[_currentPage].isLast)
                        TextButton(
                          onPressed: _goToAuth,
                          style: TextButton.styleFrom(
                            foregroundColor:
                                isDark ? Colors.white70 : Colors.black54,
                          ),
                          child: Text(
                            'Log In',
                            style:
                                GoogleFonts.nunito(fontWeight: FontWeight.w700),
                          ),
                        ),
                    ],
                  ),
                ),

                // Content Area with Glassmorphism
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    physics: const BouncingScrollPhysics(),
                    onPageChanged: (index) =>
                        setState(() => _currentPage = index),
                    itemCount: _pages.length,
                    itemBuilder: (context, index) {
                      // Only animate the content currently visible
                      if (index == _currentPage) {
                        return _buildGlassCard(_pages[index], isDark);
                      } else {
                        return const SizedBox(); // Optimization
                      }
                    },
                  ),
                ),

                // Bottom Navigation (Morphing Button)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 48),
                  child: _MorphingNavButton(
                    isLastPage: _pages[_currentPage].isLast,
                    color: activeColor,
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

  Widget _buildGlassCard(OnboardingContent content, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.white.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.white.withValues(alpha: 0.5),
                ),
                boxShadow: [
                  BoxShadow(
                    color: content.color.withValues(alpha: 0.15),
                    blurRadius: 30,
                    spreadRadius: 5,
                    offset: const Offset(0, 10),
                  )
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Animated Icon
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 500),
                    transitionBuilder: (child, animation) =>
                        ScaleTransition(scale: animation, child: child),
                    child: Container(
                      key: ValueKey(content.icon),
                      height: 100,
                      width: 100,
                      decoration: BoxDecoration(
                        color: content.color.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: FaIcon(content.icon,
                            size: 45, color: content.color),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Animated Title
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    child: Text(
                      content.title,
                      key: ValueKey(content.title),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                        height: 1.1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Animated Subtitle
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    child: Text(
                      content.subtitle,
                      key: ValueKey(content.subtitle),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.nunito(
                        fontSize: 18,
                        color: isDark ? Colors.grey[300] : Colors.grey[600],
                        height: 1.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
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
                          const Icon(Icons.arrow_forward_rounded,
                              color: Colors.white),
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
  final IconData icon;
  final Color color;
  final bool isLast;

  OnboardingContent({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.isLast = false,
  });
}
