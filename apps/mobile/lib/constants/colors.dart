import 'package:flutter/material.dart';

class AppColors {
  // EduPoa brand colors
  static const Color edupoaBlue = Color(0xFF2B4E9A); // Primary Blue
  static const Color edupoaTeal = Color(0xFF2D9A7C); // Secondary/Accent Teal
  static const Color edupoaDark = Color(0xFF1F2633); // Footer/Dark

  // Primary Colors (Mapped to EduPoa)
  static const Color primaryBlue = edupoaBlue;
  // keeping primaryPurple for backward compatibility strictly as an alias for migration
  static const Color primaryPurple = edupoaBlue;
  static const Color primaryDark = edupoaDark;

  // Accent Colors
  static const Color accentTeal = edupoaTeal;
  static const Color accentGreen = Color(0xFF2D9A7C); // Match EduPoa Teal/Green
  static const Color accentEmerald = Color(0xFF10b981);

  // Secondary Colors
  static const Color secondaryBlue = Color(0xFF3498db);
  // These might still be used for secondary elements, keeping them distinct but complementary
  static const Color secondaryViolet = Color(0xFF8b5cf6);
  static const Color secondaryPink = Color(0xFFec4899);

  static const Color black = Color(0xFF0f0f23);
  static const Color white = Color(0xFFFFFFFF);

  // App Theme Aliases - This is what main.dart uses
  static const Color primary = Color(0xFF2563EB); // Premium Blue
  static const Color secondary = edupoaTeal;
  static const Color accent = edupoaTeal;

  // Enhanced UI Colors
  static const Color overlay = Color(0x80000000);
  static const Color overlayLight = Color(0x40000000);
  static const Color shimmerBase = Color(0xFFF5F5F5);
  static const Color shimmerHighlight = white;
  static const Color shimmerBaseDark = Color(0xFF252525);
  static const Color shimmerHighlightDark = Color(0xFF2C2C2C);

  // Light Mode Backgrounds - Softer premium off-white
  static const Color background = Color(0xFFF9FAFB);
  static const Color surface = white;
  static const Color surfaceVariant = Color(0xFFF3F4F6);
  static const Color surfaceElevated = white;

  // Dark Mode Colors - Deep Charcoal/Zinc (Premium)
  static const Color backgroundDark = Color(0xFF0B0B0F);
  static const Color surfaceDark = Color(0xFF16161E);
  static const Color surfaceVariantDark = Color(0xFF1F1F29);
  static const Color surfaceElevatedDark = Color(0xFF18181B);
  static const Color textDark = Color(0xFFF9FAFB);
  static const Color textSecondaryDark = Color(0xFF9CA3AF);

  // Text colors (Light mode)
  static const Color text = Color(0xFF111827); // Deep Charcoal
  static const Color textSecondary = Color(0xFF4B5563);
  static const Color textLight = Color(0xFF9CA3AF);
  static const Color textInverse = white;

  // Border colors - Softer, more subtle
  static const Color border = Color(0xFFE5E7EB);
  static const Color borderDark = Color(0xFF222222);

  // Status colors
  static const Color success = Color(0xFF10b981);
  static const Color warning = Color(0xFFf59e0b);
  static const Color error = Color(0xFFef4444);
  static const Color info = Color(0xFF3b82f6);

  // Feature Card Colors - Updated to respect the new palette where appropriate
  static const Color cardBlue = edupoaBlue;
  static const Color cardGreen = edupoaTeal;
  static const Color cardPurple = Color(0xFF8b5cf6);
  static const Color cardPink = Color(0xFFec4899);
  static const Color cardOrange = Color(0xFFf97316);
  static const Color cardTeal = Color(0xFF14b8a6);

  // Legacy Google Colors (for compatibility)
  static const Color googleBlue = secondaryBlue;
  static const Color googleRed = error;
  static const Color googleYellow = warning;
  static const Color googleGreen = accentGreen;

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [edupoaBlue, Color(0xFF3B5EAA)], // Blue gradient
  );

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [edupoaBlue, Color(0xFF203A75), edupoaTeal],
    stops: [0.0, 0.6, 1.0],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [edupoaTeal, Color(0xFF3DBFA0)],
  );

  static const LinearGradient darkGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF000000), Color(0xFF121212)],
  );

  static const LinearGradient glassGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0x30FFFFFF), Color(0x10FFFFFF)],
  );

  // Achievement & Discovery Colors (For Gamification)
  static const Color achievementGreen = Color(
    0xFF22C55E,
  ); // Modern Emerald/Green
  static const Color discoveryOrange = Color(
    0xFFF97316,
  ); // Vibrant Discovery Orange
  static const Color focusYellow = Color(0xFFEAB308); // Strong Attention Yellow
  static const Color sifaGold = Color(
    0xFFD4AF37,
  ); // Gold for "Sifa the Lion" badges

  // Backward compatibility aliases
  static const LinearGradient secondaryGradient = accentGradient;
  static const LinearGradient googleGradient = heroGradient;
  static const LinearGradient blackGradient = darkGradient;
}
