import 'package:flutter/material.dart';
import 'package:math_expressions/math_expressions.dart';
import '../../constants/colors.dart';

class CalculatorScreen extends StatefulWidget {
  const CalculatorScreen({super.key});

  @override
  State<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends State<CalculatorScreen> {
  String _expression = '';
  String _result = '0';
  bool _isDegree = true;

  String _convertDegreesToRadians(String input) {
    if (!_isDegree) return input;
    StringBuffer buffer = StringBuffer();
    int i = 0;
    while (i < input.length) {
      if (i + 3 <= input.length &&
          ['sin', 'cos', 'tan'].contains(input.substring(i, i + 3))) {
        String func = input.substring(i, i + 3);
        buffer.write(func);
        i += 3;
        if (i < input.length && input[i] == '(') {
          buffer.write('(');
          i++;
          int depth = 1;
          int start = i;
          while (i < input.length && depth > 0) {
            if (input[i] == '(') depth++;
            if (input[i] == ')') depth--;
            i++;
          }
          if (depth == 0) {
            String content = input.substring(start, i - 1);
            String convertedContent = _convertDegreesToRadians(content);
            buffer.write(convertedContent);
            buffer.write(' * (3.14159265359/180.0))');
          } else {
            buffer.write(input.substring(start));
          }
        }
      } else {
        buffer.write(input[i]);
        i++;
      }
    }
    return buffer.toString();
  }

  void _onPressed(String text) {
    setState(() {
      if (text == 'C') {
        _expression = '';
        _result = '0';
      } else if (text == '⌫') {
        if (_expression.isNotEmpty) {
          _expression = _expression.substring(0, _expression.length - 1);
        }
      } else if (text == '=') {
        try {
          GrammarParser p = GrammarParser();
          Expression exp = p.parse(
            _convertDegreesToRadians(
              _expression,
            ).replaceAll('×', '*').replaceAll('÷', '/'),
          );
          ContextModel cm = ContextModel();
          // ignore: deprecated_member_use
          double eval = exp.evaluate(EvaluationType.REAL, cm);

          // Format result to remove trailing .0 if integer
          if (eval % 1 == 0) {
            _result = eval.toInt().toString();
          } else {
            _result = eval.toString();
          }
        } catch (e) {
          _result = 'Error';
        }
      } else if (['sin', 'cos', 'tan', 'sqrt'].contains(text)) {
        _expression += '$text(';
      } else {
        _expression += text;
      }
    });
  }

  Widget _buildButton(
    String text,
    ThemeData theme,
    double buttonHeight, {
    Color? color,
    Color? textColor,
  }) {
    // Scale font size based on button height
    final fontSize = (buttonHeight * 0.35).clamp(14.0, 24.0);
    final margin = (buttonHeight * 0.08).clamp(4.0, 8.0);
    final borderRadius = (buttonHeight * 0.2).clamp(8.0, 16.0);

    return Expanded(
      child: Container(
        margin: EdgeInsets.all(margin),
        height: buttonHeight,
        child: ElevatedButton(
          onPressed: () => _onPressed(text),
          style: ElevatedButton.styleFrom(
            backgroundColor: color ?? theme.cardColor,
            foregroundColor: textColor ?? theme.colorScheme.onSurface,
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(borderRadius),
            ),
            elevation: 2,
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: margin,
                vertical: margin / 2,
              ),
              child: Text(
                text,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Calculator',
          style: TextStyle(color: theme.colorScheme.onSurface),
        ),
        backgroundColor:
            theme.appBarTheme.backgroundColor ?? theme.colorScheme.surface,
        elevation: 1,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: TextButton(
              onPressed: () {
                setState(() {
                  _isDegree = !_isDegree;
                });
              },
              style: TextButton.styleFrom(
                backgroundColor: theme.colorScheme.primaryContainer,
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: Text(
                _isDegree ? 'DEG' : 'RAD',
                style: TextStyle(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final availableHeight = constraints.maxHeight;
            final availableWidth = constraints.maxWidth;

            // Calculate proportions based on screen size
            final displayHeight = availableHeight * 0.22;
            final buttonAreaHeight = availableHeight * 0.78;

            // 6 rows of buttons with margins
            final buttonHeight = (buttonAreaHeight / 6) - 8;

            // Limit button size for wide screens
            final maxButtonWidth = (availableWidth / 5) - 8;
            final finalButtonHeight = buttonHeight > maxButtonWidth
                ? maxButtonWidth
                : buttonHeight;

            // Responsive font sizes for display
            final expressionFontSize = (displayHeight * 0.2).clamp(18.0, 32.0);
            final resultFontSize = (displayHeight * 0.35).clamp(28.0, 48.0);

            return Column(
              children: [
                // Display area
                SizedBox(
                  height: displayHeight,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: (displayHeight * 0.08).clamp(8.0, 16.0),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Text(
                              _expression.isEmpty ? ' ' : _expression,
                              style: TextStyle(
                                fontSize: expressionFontSize,
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                              maxLines: 1,
                            ),
                          ),
                        ),
                        SizedBox(
                          height: (displayHeight * 0.06).clamp(4.0, 12.0),
                        ),
                        Flexible(
                          flex: 2,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Text(
                              _result,
                              style: TextStyle(
                                fontSize: resultFontSize,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                              ),
                              maxLines: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Button grid area
                Expanded(
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: (availableWidth * 0.02).clamp(8.0, 16.0),
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(
                          (availableWidth * 0.06).clamp(16.0, 32.0),
                        ),
                      ),
                    ),
                    child: Column(
                      children: [
                        // Row 1: Scientific functions
                        Expanded(
                          child: Row(
                            children: [
                              _buildButton(
                                'sin',
                                theme,
                                finalButtonHeight,
                                color: theme.cardColor,
                              ),
                              _buildButton(
                                'cos',
                                theme,
                                finalButtonHeight,
                                color: theme.cardColor,
                              ),
                              _buildButton(
                                'tan',
                                theme,
                                finalButtonHeight,
                                color: theme.cardColor,
                              ),
                              _buildButton(
                                'sqrt',
                                theme,
                                finalButtonHeight,
                                color: theme.cardColor,
                              ),
                              _buildButton(
                                '^',
                                theme,
                                finalButtonHeight,
                                color: theme.cardColor,
                              ),
                            ],
                          ),
                        ),
                        // Row 2: Clear, parentheses, divide
                        Expanded(
                          child: Row(
                            children: [
                              _buildButton(
                                'C',
                                theme,
                                finalButtonHeight,
                                color: AppColors.googleRed.withValues(
                                  alpha: 0.1,
                                ),
                                textColor: AppColors.googleRed,
                              ),
                              _buildButton(
                                '(',
                                theme,
                                finalButtonHeight,
                                color: theme.cardColor,
                              ),
                              _buildButton(
                                ')',
                                theme,
                                finalButtonHeight,
                                color: theme.cardColor,
                              ),
                              _buildButton(
                                '÷',
                                theme,
                                finalButtonHeight,
                                color: AppColors.googleBlue,
                                textColor: Colors.white,
                              ),
                            ],
                          ),
                        ),
                        // Row 3: 7, 8, 9, multiply
                        Expanded(
                          child: Row(
                            children: [
                              _buildButton('7', theme, finalButtonHeight),
                              _buildButton('8', theme, finalButtonHeight),
                              _buildButton('9', theme, finalButtonHeight),
                              _buildButton(
                                '×',
                                theme,
                                finalButtonHeight,
                                color: AppColors.googleBlue,
                                textColor: Colors.white,
                              ),
                            ],
                          ),
                        ),
                        // Row 4: 4, 5, 6, subtract
                        Expanded(
                          child: Row(
                            children: [
                              _buildButton('4', theme, finalButtonHeight),
                              _buildButton('5', theme, finalButtonHeight),
                              _buildButton('6', theme, finalButtonHeight),
                              _buildButton(
                                '-',
                                theme,
                                finalButtonHeight,
                                color: AppColors.googleBlue,
                                textColor: Colors.white,
                              ),
                            ],
                          ),
                        ),
                        // Row 5: 1, 2, 3, add
                        Expanded(
                          child: Row(
                            children: [
                              _buildButton('1', theme, finalButtonHeight),
                              _buildButton('2', theme, finalButtonHeight),
                              _buildButton('3', theme, finalButtonHeight),
                              _buildButton(
                                '+',
                                theme,
                                finalButtonHeight,
                                color: AppColors.googleBlue,
                                textColor: Colors.white,
                              ),
                            ],
                          ),
                        ),
                        // Row 6: 0, decimal, backspace, equals
                        Expanded(
                          child: Row(
                            children: [
                              _buildButton('0', theme, finalButtonHeight),
                              _buildButton('.', theme, finalButtonHeight),
                              _buildButton(
                                '⌫',
                                theme,
                                finalButtonHeight,
                                color: AppColors.googleYellow.withValues(
                                  alpha: 0.1,
                                ),
                                textColor: AppColors.googleYellow,
                              ),
                              _buildButton(
                                '=',
                                theme,
                                finalButtonHeight,
                                color: AppColors.googleGreen,
                                textColor: Colors.white,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
