import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class QuizWidget extends StatefulWidget {
  final Map<String, dynamic> quizData;
  final Function(int score) onComplete;

  const QuizWidget({
    super.key,
    required this.quizData,
    required this.onComplete,
  });

  @override
  State<QuizWidget> createState() => _QuizWidgetState();
}

class _QuizWidgetState extends State<QuizWidget> {
  int _currentIndex = 0;
  int _score = 0;
  int? _selectedOptionIndex;
  bool _isAnswered = false;
  bool _isCompleted = false;

  void _handleAnswer(int optionIndex) {
    if (_isAnswered) return;

    final correctIndex =
        widget.quizData['questions'][_currentIndex]['correct_index'];

    setState(() {
      _selectedOptionIndex = optionIndex;
      _isAnswered = true;
      if (optionIndex == correctIndex) {
        _score++;
      }
    });
  }

  void _nextQuestion() {
    final questions = widget.quizData['questions'] as List;
    if (_currentIndex < questions.length - 1) {
      setState(() {
        _currentIndex++;
        _selectedOptionIndex = null;
        _isAnswered = false;
      });
    } else {
      setState(() {
        _isCompleted = true;
      });
      widget.onComplete(_score);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final questions = widget.quizData['questions'] as List;
    final currentQuestion = questions[_currentIndex];
    // final title = widget.quizData['title'] ?? 'Quiz'; // Unused

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      width: double.infinity, // Take full width
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? const Color(0xFF252525)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.primaryColor.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: _isCompleted
            ? _buildSummary(theme, questions.length)
            : _buildQuestion(theme, currentQuestion, questions.length),
      ),
    );
  }

  Widget _buildQuestion(
    ThemeData theme,
    dynamic questionData,
    int totalQuestions,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Question ${_currentIndex + 1}/$totalQuestions",
              style: GoogleFonts.outfit(
                color: theme.primaryColor,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: theme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                "Score: $_score",
                style: GoogleFonts.outfit(
                  color: theme.primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Question Text
        Text(
          questionData['question'],
          style: GoogleFonts.dmSans(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),

        // Options
        ...List.generate(questionData['options'].length, (index) {
          final option = questionData['options'][index];
          final correctIndex = questionData['correct_index'];

          Color borderColor = theme.dividerColor.withValues(alpha: 0.2);
          Color bgColor = Colors.transparent;
          IconData? icon;

          if (_isAnswered) {
            if (index == correctIndex) {
              borderColor = Colors.green;
              bgColor = Colors.green.withValues(alpha: 0.1);
              icon = Icons.check_circle;
            } else if (index == _selectedOptionIndex) {
              borderColor = Colors.red;
              bgColor = Colors.red.withValues(alpha: 0.1);
              icon = Icons.cancel;
            }
          }

          return GestureDetector(
            onTap: () => _handleAnswer(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _selectedOptionIndex == index && !_isAnswered
                      ? theme.primaryColor
                      : borderColor,
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      option,
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  if (icon != null) Icon(icon, size: 18, color: borderColor),
                ],
              ),
            ),
          );
        }),

        const SizedBox(height: 12),

        // Next Button
        if (_isAnswered)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _nextQuestion,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                _currentIndex == totalQuestions - 1
                    ? "Finish Quiz"
                    : "Next Question",
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSummary(ThemeData theme, int total) {
    final percentage = (_score / total) * 100;
    return Column(
      children: [
        const Icon(Icons.emoji_events_rounded, size: 48, color: Colors.amber),
        const SizedBox(height: 16),
        Text(
          "Quiz Completed!",
          style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          "You scored $_score out of $total",
          style: GoogleFonts.dmSans(
            fontSize: 16,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 24),
        LinearProgressIndicator(
          value: _score / total,
          minHeight: 8,
          borderRadius: BorderRadius.circular(4),
          color: percentage > 50 ? Colors.green : Colors.orange,
          backgroundColor: theme.dividerColor.withValues(alpha: 0.1),
        ),
      ],
    );
  }
}
