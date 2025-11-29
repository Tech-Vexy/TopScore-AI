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

  Widget _buildButton(String text, {Color? color, Color? textColor}) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.all(8),
        child: ElevatedButton(
          onPressed: () => _onPressed(text),
          style: ElevatedButton.styleFrom(
            backgroundColor: color ?? Colors.white,
            foregroundColor: textColor ?? AppColors.text,
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calculator', style: TextStyle(color: AppColors.text)),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: AppColors.text),
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
                    style: const TextStyle(fontSize: 32, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _result,
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: AppColors.text,
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
                color: Colors.grey[100],
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      _buildButton('sin', color: AppColors.surfaceVariant),
                      _buildButton('cos', color: AppColors.surfaceVariant),
                      _buildButton('tan', color: AppColors.surfaceVariant),
                      _buildButton('sqrt', color: AppColors.surfaceVariant),
                      _buildButton('^', color: AppColors.surfaceVariant),
                    ],
                  ),
                  Row(
                    children: [
                      _buildButton('C', color: Colors.red[100], textColor: Colors.red),
                      _buildButton('(', color: AppColors.surfaceVariant),
                      _buildButton(')', color: AppColors.surfaceVariant),
                      _buildButton('÷', color: AppColors.primary, textColor: Colors.white),
                    ],
                  ),
                  Row(
                    children: [
                      _buildButton('7'),
                      _buildButton('8'),
                      _buildButton('9'),
                      _buildButton('×', color: AppColors.primary, textColor: Colors.white),
                    ],
                  ),
                  Row(
                    children: [
                      _buildButton('4'),
                      _buildButton('5'),
                      _buildButton('6'),
                      _buildButton('-', color: AppColors.primary, textColor: Colors.white),
                    ],
                  ),
                  Row(
                    children: [
                      _buildButton('1'),
                      _buildButton('2'),
                      _buildButton('3'),
                      _buildButton('+', color: AppColors.primary, textColor: Colors.white),
                    ],
                  ),
                  Row(
                    children: [
                      _buildButton('0'),
                      _buildButton('.'),
                      _buildButton('⌫', color: Colors.orange[100], textColor: Colors.orange),
                      _buildButton('=', color: AppColors.secondary, textColor: Colors.white),
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
