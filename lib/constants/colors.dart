import 'package:flutter/material.dart';

class AppColors {
  // Kenyan flag inspired colors
  static const Color black = Color(0xFF000000);
  static const Color red = Color(0xFFBB0000); // Vibrant Red
  static const Color green = Color(0xFF006600); // Dark Green
  static const Color white = Color(0xFFFFFFFF);
  
  static const Color primary = green;
  static const Color secondary = red;
  static const Color accent = black;
  static const Color background = Color(0xFFF5F5F5); // Light Grey for background
  static const Color surface = white;
  static const Color surfaceVariant = Color(0xFFEEEEEE); // Slightly darker than surface
  
  // Text colors
  static const Color text = black;
  static const Color textSecondary = Color(0xFF424242);
  static const Color textLight = Color(0xFF757575);
  static const Color textInverse = white;
  
  // Status colors
  static const Color success = green;
  static const Color warning = Color(0xFFFFA000);
  static const Color error = red;
  static const Color info = Color(0xFF1976D2);
  
  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [green, Color(0xFF004d00)],
  );
  
  static const LinearGradient secondaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [red, Color(0xFF990000)],
  );
  
  static const LinearGradient blackGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF424242), black],
  );
}
