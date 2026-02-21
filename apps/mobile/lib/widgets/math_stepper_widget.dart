import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_markdown/flutter_markdown.dart'; // Ensure you have this

class MathStepperWidget extends StatefulWidget {
  final List<String> steps;
  final String? finalAnswer;

  const MathStepperWidget({super.key, required this.steps, this.finalAnswer});

  @override
  State<MathStepperWidget> createState() => _MathStepperWidgetState();
}

class _MathStepperWidgetState extends State<MathStepperWidget> {
  int _currentStep = 0;

  void _nextStep() {
    if (_currentStep <
        widget.steps.length + (widget.finalAnswer != null ? 1 : 0) - 1) {
      setState(() {
        _currentStep++;
      });
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final totalSteps = widget.steps.length;
    final showFinalAnswer =
        widget.finalAnswer != null && _currentStep == totalSteps;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.primaryColor.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: theme.primaryColor.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.calculate_outlined,
                      size: 18,
                      color: theme.primaryColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "Step-by-Step Solver",
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        color: theme.primaryColor,
                      ),
                    ),
                  ],
                ),
                Text(
                  showFinalAnswer
                      ? "Complete"
                      : "Step ${_currentStep + 1} of $totalSteps",
                  style: GoogleFonts.firaCode(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),

          // Content Area
          Padding(
            padding: const EdgeInsets.all(20),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: showFinalAnswer
                  ? _buildFinalAnswer(theme)
                  : _buildStepContent(theme, widget.steps[_currentStep]),
            ),
          ),

          // Controls
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Previous Button
                if (_currentStep > 0)
                  TextButton.icon(
                    onPressed: _previousStep,
                    icon: const Icon(Icons.arrow_back, size: 16),
                    label: const Text("Back"),
                    style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.onSurface.withValues(
                        alpha: 0.6,
                      ),
                    ),
                  )
                else
                  const SizedBox(width: 80), // Spacer
                // Next Button
                if (!showFinalAnswer)
                  ElevatedButton.icon(
                    onPressed: _nextStep,
                    icon: const Icon(Icons.arrow_forward, size: 16),
                    label: Text(
                      _currentStep == totalSteps - 1 &&
                              widget.finalAnswer != null
                          ? "Reveal Answer"
                          : "Next Step",
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
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

  Widget _buildStepContent(ThemeData theme, String content) {
    return SizedBox(
      key: ValueKey<int>(_currentStep), // For animation
      width: double.infinity,
      child: MarkdownBody(
        data: content,
        styleSheet: MarkdownStyleSheet(
          p: GoogleFonts.dmSans(
            fontSize: 18,
            height: 1.5,
            color: theme.colorScheme.onSurface,
          ),
          code: GoogleFonts.firaCode(
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            color: theme.primaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildFinalAnswer(ThemeData theme) {
    return Container(
      key: const ValueKey('final'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Final Answer",
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.green,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          MarkdownBody(
            data: widget.finalAnswer!,
            styleSheet: MarkdownStyleSheet(
              p: GoogleFonts.dmSans(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
