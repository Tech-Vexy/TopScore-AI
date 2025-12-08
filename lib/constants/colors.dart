import 'package:flutter/material.dart';

class AppColors {
  // Google Brand Colors
  static const Color googleBlue = Color(0xFF4285F4);
  static const Color googleRed = Color(0xFFDB4437);
  static const Color googleYellow = Color(0xFFF4B400);
  static const Color googleGreen = Color(0xFF0F9D58);
  
  static const Color black = Color(0xFF202124); // Google Dark Grey
  static const Color white = Color(0xFFFFFFFF);
  
  static const Color primary = googleBlue;
  static const Color secondary = googleRed;
  static const Color accent = googleYellow;
  static const Color background = Color(0xFFF8F9FA); // Google Light Grey
  static const Color surface = white;
  static const Color surfaceVariant = Color(0xFFF1F3F4);
  
  // Dark Mode Colors
  static const Color backgroundDark = Color(0xFF121212);
  static const Color surfaceDark = Color(0xFF1E1E1E);
  static const Color surfaceVariantDark = Color(0xFF2C2C2C);
  static const Color textDark = Color(0xFFE8EAED);
  static const Color textSecondaryDark = Color(0xFF9AA0A6);
  
  // Text colors
  static const Color text = Color(0xFF202124);
  static const Color textSecondary = Color(0xFF5F6368);
  static const Color textLight = Color(0xFF80868B);
  static const Color textInverse = white;
  
  // Status colors
  static const Color success = googleGreen;
  static const Color warning = googleYellow;
  static const Color error = googleRed;
  static const Color info = googleBlue;
  
  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [googleBlue, Color(0xFF3367D6)], // Blue to Darker Blue
  );
  
  static const LinearGradient secondaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [googleRed, Color(0xFFC5221F)], // Red to Darker Red
  );
  
  static const LinearGradient googleGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [googleBlue, googleRed, googleYellow, googleGreen],
  );
  
  static const LinearGradient blackGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF424242), black],
  );
}
