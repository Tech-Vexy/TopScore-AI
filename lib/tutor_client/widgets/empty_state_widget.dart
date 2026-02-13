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
  // Default fallback suggestions if dynamic ones fail
  static const _defaultSuggestions = [
    Suggestion('🧪', 'Explain photosynthesis', 'in simple terms'),
    Suggestion('📐', 'Help me solve', 'a quadratic equation'),
    Suggestion('🌍', 'What causes', 'earthquakes?'),
    Suggestion('📝', 'Summarize', 'the French Revolution'),
    Suggestion('🔬', 'How does', 'DNA replication work?'),
    Suggestion('🧮', 'Practice', 'fraction problems'),
  ];

  @override
  Widget build(BuildContext context) {
    // Use dynamic suggestions if available, otherwise default
    final List<Suggestion> activeSuggestions =
        widget.suggestions != null && widget.suggestions!.isNotEmpty
        ? widget.suggestions!
              .map(
                (s) => Suggestion(
                  s['emoji'] ?? '✨',
                  s['title'] ?? '',
                  s['subtitle'] ?? '',
                ),
              )
              .toList()
        : _defaultSuggestions;

    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 600;
    final crossAxisCount = isCompact ? 2 : 3;

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
                    'Ask me anything or pick a topic below',
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

                  // Suggestion chips grid
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: isCompact ? 2.2 : 2.8,
                    ),
                    itemCount: activeSuggestions.length,
                    itemBuilder: (context, index) {
                      final suggestion = activeSuggestions[index];
                      return _SuggestionChip(
                        suggestion: suggestion,
                        isDark: widget.isDark,
                        onTap: () {
                          widget.onSuggestionTap?.call(
                            '${suggestion.title} ${suggestion.subtitle}',
                          );
                        },
                      );
                    },
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// --- Data model ---

class Suggestion {
  final String emoji;
  final String title;
  final String subtitle;

  const Suggestion(this.emoji, this.title, this.subtitle);
}

// --- Suggestion chip widget ---

class _SuggestionChip extends StatefulWidget {
  final Suggestion suggestion;
  final bool isDark;
  final VoidCallback onTap;

  const _SuggestionChip({
    required this.suggestion,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_SuggestionChip> createState() => _SuggestionChipState();
}

class _SuggestionChipState extends State<_SuggestionChip> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final bg = widget.isDark
        ? Colors.white.withValues(alpha: _isHovered ? 0.1 : 0.06)
        : Colors.white.withValues(alpha: _isHovered ? 1.0 : 0.85);
    final borderColor = widget.isDark
        ? Colors.white.withValues(alpha: _isHovered ? 0.2 : 0.08)
        : const Color(0xFFDEE2E6).withValues(alpha: _isHovered ? 0.8 : 0.5);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: 1),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.suggestion.emoji,
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 4),
              Text(
                widget.suggestion.title,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: widget.isDark ? Colors.white : const Color(0xFF1A1A2E),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                widget.suggestion.subtitle,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  color: widget.isDark
                      ? Colors.white.withValues(alpha: 0.5)
                      : const Color(0xFF6C757D),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
