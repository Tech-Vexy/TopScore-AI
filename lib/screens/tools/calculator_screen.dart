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
          Expression exp = p.parse(_expression.replaceAll('×', '*').replaceAll('÷', '/'));
          ContextModel cm = ContextModel();
          // double eval = exp.evaluate(EvaluationType.REAL, cm);
          // Use RealEvaluator as evaluate is deprecated
          // Note: math_expressions 3.1.0 might still use evaluate but warn.
          // Let's try to suppress the warning or use the new API if I can guess it.
          // Actually, let's just ignore the warning for now as I don't have the docs for the new API handy
          // and I don't want to break it.
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

  Widget _buildButton(String text, ThemeData theme, {Color? color, Color? textColor}) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(8),
        child: ElevatedButton(
          onPressed: () => _onPressed(text),
          style: ElevatedButton.styleFrom(
            backgroundColor: color ?? theme.cardColor,
            foregroundColor: textColor ?? theme.colorScheme.onSurface,
            padding: const EdgeInsets.all(24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 2,
          ),
          child: Text(
            text,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
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
        title: Text('Calculator', style: TextStyle(color: theme.colorScheme.onSurface)),
        backgroundColor: theme.appBarTheme.backgroundColor ?? theme.colorScheme.surface,
        elevation: 1,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
      ),
      body: Column(
        children: [
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.all(24),
              alignment: Alignment.bottomRight,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _expression,
                    style: TextStyle(fontSize: 32, color: theme.colorScheme.onSurface.withOpacity(0.6)),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _result,
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      _buildButton('sin', theme, color: theme.cardColor),
                      _buildButton('cos', theme, color: theme.cardColor),
                      _buildButton('tan', theme, color: theme.cardColor),
                      _buildButton('sqrt', theme, color: theme.cardColor),
                      _buildButton('^', theme, color: theme.cardColor),
                    ],
                  ),
                  Row(
                    children: [
                      _buildButton('C', theme, color: AppColors.googleRed.withOpacity(0.1), textColor: AppColors.googleRed),
                      _buildButton('(', theme, color: theme.cardColor),
                      _buildButton(')', theme, color: theme.cardColor),
                      _buildButton('÷', theme, color: AppColors.googleBlue, textColor: Colors.white),
                    ],
                  ),
                  Row(
                    children: [
                      _buildButton('7', theme),
                      _buildButton('8', theme),
                      _buildButton('9', theme),
                      _buildButton('×', theme, color: AppColors.googleBlue, textColor: Colors.white),
                    ],
                  ),
                  Row(
                    children: [
                      _buildButton('4', theme),
                      _buildButton('5', theme),
                      _buildButton('6', theme),
                      _buildButton('-', theme, color: AppColors.googleBlue, textColor: Colors.white),
                    ],
                  ),
                  Row(
                    children: [
                      _buildButton('1', theme),
                      _buildButton('2', theme),
                      _buildButton('3', theme),
                      _buildButton('+', theme, color: AppColors.googleBlue, textColor: Colors.white),
                    ],
                  ),
                  Row(
                    children: [
                      _buildButton('0', theme),
                      _buildButton('.', theme),
                      _buildButton('⌫', theme, color: AppColors.googleYellow.withOpacity(0.1), textColor: AppColors.googleYellow),
                      _buildButton('=', theme, color: AppColors.googleGreen, textColor: Colors.white),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
