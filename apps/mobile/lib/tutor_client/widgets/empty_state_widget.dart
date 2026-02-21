import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class EmptyStateWidget extends StatefulWidget {
  final bool isDark;
  final ThemeData theme;
  final void Function(String prompt)? onSuggestionTap;
  final List<Map<String, String>>? suggestions;

  const EmptyStateWidget({
    super.key,
    required this.isDark,
    required this.theme,
    this.onSuggestionTap,
    this.suggestions,
  });

  @override
  State<EmptyStateWidget> createState() => _EmptyStateWidgetState();
}

class _EmptyStateWidgetState extends State<EmptyStateWidget> {
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 600;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Animated gradient background
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(seconds: 20),
          builder: (context, value, child) {
            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: widget.isDark
                      ? [
                          Color.lerp(
                            const Color(0xFF0A0A0A),
                            const Color(0xFF1A1A2E),
                            value,
                          )!,
                          Color.lerp(
                            const Color(0xFF16213E),
                            const Color(0xFF0F3460),
                            value,
                          )!,
                          Color.lerp(
                            const Color(0xFF1A1A2E),
                            const Color(0xFF0A0A0A),
                            value,
                          )!,
                        ]
                      : [
                          Color.lerp(
                            const Color(0xFFF8F9FA),
                            const Color(0xFFE9ECEF),
                            value,
                          )!,
                          Color.lerp(
                            const Color(0xFFDEE2E6),
                            const Color(0xFFF8F9FA),
                            value,
                          )!,
                        ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            );
          },
          onEnd: () {
            if (mounted) {
              setState(() {});
            }
          },
        ),

        // Floating particles/orbs effect
        if (widget.isDark) ...[
          Positioned(
            top: 100,
            left: 100,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 20.0),
              duration: const Duration(seconds: 4),
              curve: Curves.easeInOut,
              builder: (context, value, child) {
                return Transform.translate(
                  offset: Offset(0, value),
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Colors.blue.withValues(alpha: 0.1),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                );
              },
              onEnd: () {
                if (mounted) setState(() {});
              },
            ),
          ),
          Positioned(
            bottom: 150,
            right: 150,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: -15.0),
              duration: const Duration(seconds: 5),
              curve: Curves.easeInOut,
              builder: (context, value, child) {
                return Transform.translate(
                  offset: Offset(value, 0),
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Colors.purple.withValues(alpha: 0.08),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                );
              },
              onEnd: () {
                if (mounted) setState(() {});
              },
            ),
          ),
        ],

        // Content overlay - Centered
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),

                  // Icon
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: widget.isDark
                            ? [const Color(0xFF6C63FF), const Color(0xFF9B59B6)]
                            : [
                                const Color(0xFF7C4DFF),
                                const Color(0xFFAB47BC),
                              ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6C63FF).withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.auto_awesome,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Title
                  Text(
                    'What would you like to learn?',
                    style: GoogleFonts.inter(
                      fontSize: isCompact ? 22 : 26,
                      fontWeight: FontWeight.w700,
                      color: widget.isDark
                          ? Colors.white
                          : const Color(0xFF1A1A2E),
                      height: 1.2,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 8),

                  // Subtitle
                  Text(
                    'Ask me anything to get started',
                    style: GoogleFonts.inter(
                      fontSize: isCompact ? 14 : 15,
                      fontWeight: FontWeight.w400,
                      color: widget.isDark
                          ? Colors.white.withValues(alpha: 0.5)
                          : const Color(0xFF6C757D),
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
