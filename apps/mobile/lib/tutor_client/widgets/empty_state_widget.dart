import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class EmptyStateWidget extends StatefulWidget {
  final bool isDark;
  final ThemeData theme;
  final void Function(String prompt)? onSuggestionTap;
  final List<Map<String, String>>? suggestions;
  final String? userName;

  const EmptyStateWidget({
    super.key,
    required this.isDark,
    required this.theme,
    this.onSuggestionTap,
    this.suggestions,
    this.userName,
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
        // Static background gradient instead of animation
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: widget.isDark
                  ? const [
                      Color(0xFF0A0A0A),
                      Color(0xFF16213E),
                    ]
                  : const [
                      Color(0xFFF8F9FA),
                      Color(0xFFE9ECEF),
                    ],
            ),
          ),
        ),

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

                  // Removed auto_awesome icon.

                  const SizedBox(height: 20),

                  // Gradient Greeting
                  ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      colors: widget.isDark
                          ? [
                              const Color(0xFF9B72CB),
                              const Color(0xFFD96570),
                            ]
                          : [
                              const Color(0xFF4285F4),
                              const Color(0xFF9B72CB),
                            ],
                    ).createShader(bounds),
                    child: Text(
                      widget.userName != null && widget.userName!.isNotEmpty
                          ? 'Hello, ${widget.userName}'
                          : 'Hello, Learner',
                      style: GoogleFonts.outfit(
                        fontSize: isCompact ? 32 : 40,
                        fontWeight: FontWeight.w600,
                        color:
                            Colors.white, // Color is ignored due to ShaderMask
                        height: 1.2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Subtitle
                  Text(
                    'What can I help you learn today?',
                    style: GoogleFonts.inter(
                      fontSize: isCompact ? 16 : 18,
                      fontWeight: FontWeight.w400,
                      color: widget.isDark
                          ? Colors.white.withValues(alpha: 0.7)
                          : const Color(0xFF4A4A4A),
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 48),

                  // Central Suggestions Wrap
                  if (widget.suggestions != null &&
                      widget.suggestions!.isNotEmpty)
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      alignment: WrapAlignment.center,
                      children: widget.suggestions!.map((suggestion) {
                        return _buildStaggeredChip(suggestion);
                      }).toList(),
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

  Widget _buildStaggeredChip(Map<String, String> suggestion) {
    final emoji = suggestion['emoji'] ?? '✨';
    final text = suggestion['title'] ?? '';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (widget.onSuggestionTap != null) {
            widget.onSuggestionTap!(text);
          }
        },
        borderRadius: BorderRadius.circular(24),
        hoverColor: widget.isDark
            ? const Color(0xFF4285F4).withValues(alpha: 0.1)
            : const Color(0xFF4285F4).withValues(alpha: 0.05),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: widget.isDark ? const Color(0xFF1E1F22) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: widget.isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.grey.withValues(alpha: 0.2),
              width: 1,
            ),
            boxShadow: widget.isDark
                ? []
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Text(
                text,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: widget.isDark
                      ? Colors.white.withValues(alpha: 0.9)
                      : const Color(0xFF2C2C2C),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
