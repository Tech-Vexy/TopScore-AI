import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class GeminiReasoningView extends StatefulWidget {
  final String content;
  final bool isThinking; // True if the AI is still generating thoughts

  const GeminiReasoningView({
    super.key,
    required this.content,
    required this.isThinking,
  });

  @override
  State<GeminiReasoningView> createState() => _GeminiReasoningViewState();
}

class _GeminiReasoningViewState extends State<GeminiReasoningView>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    // Create the "Breathing" animation for the active state
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Gemini Color Palette
    final containerColor =
        isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF0F4F9);
    final activeColor =
        isDark ? const Color(0xFFA8C7FA) : const Color(0xFF0B57D0);
    final idleColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: containerColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. The Header (Always visible)
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  // Animated Sparkle Icon
                  widget.isThinking
                      ? FadeTransition(
                          opacity: _pulseController,
                          child: Icon(Icons.auto_awesome,
                              size: 16, color: activeColor),
                        )
                      : Icon(Icons.check_circle_outline,
                          size: 16, color: idleColor),

                  const SizedBox(width: 8),

                  // Status Text
                  Text(
                    widget.isThinking ? "Thinking..." : "Reasoning process",
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: widget.isThinking ? activeColor : idleColor,
                    ),
                  ),

                  const Spacer(),

                  // Expansion Arrow
                  RotationTransition(
                    turns: AlwaysStoppedAnimation(_isExpanded ? 0.5 : 0),
                    child: Icon(Icons.keyboard_arrow_down,
                        size: 18, color: idleColor),
                  ),
                ],
              ),
            ),
          ),

          // 2. The Content (Hidden by default, expandable)
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutQuart,
            child: _isExpanded
                ? Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Divider(
                            height: 1,
                            color: theme.dividerColor.withValues(alpha: 0.1)),
                        const SizedBox(height: 12),
                        MarkdownBody(
                          data: widget.content,
                          styleSheet: MarkdownStyleSheet(
                            p: GoogleFonts.firaCode(
                              // Monospace for code-like feel
                              fontSize: 12,
                              height: 1.5,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                        // Show blinking cursor if still thinking while expanded
                        if (widget.isThinking)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: FadeTransition(
                              opacity: _pulseController,
                              child: Container(
                                width: 8,
                                height: 12,
                                color: activeColor,
                              ),
                            ),
                          ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
