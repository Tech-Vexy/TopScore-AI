import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/colors.dart';

class AppTheme {
  // --- LIGHT THEME ---
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,

    // Color Scheme: Maps AppColors to Material Slots
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      tertiary: AppColors.accent,
      surface: AppColors.surface,
      error: AppColors.error,
      // onSurface/onBackground are automatically calculated for contrast
    ),

    // Scaffold & Background
    scaffoldBackgroundColor: AppColors.background,
    cardColor: AppColors.surfaceElevated,

    // Text Theme (Nunito)
    textTheme: GoogleFonts.nunitoTextTheme(
      ThemeData.light().textTheme,
    ).apply(bodyColor: AppColors.text, displayColor: AppColors.text),

    // Component Styles
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      iconTheme: IconThemeData(color: AppColors.text),
      titleTextStyle: TextStyle(
        color: AppColors.text,
        fontSize: 20,
        fontWeight: FontWeight.bold,
        fontFamily: 'Nunito', // Ensure AppBars use Nunito
      ),
    ),

    iconTheme: const IconThemeData(color: AppColors.text),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 2,
      ),
    ),
  );

  // --- DARK THEME ---
  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,

    // Color Scheme
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.dark,
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      tertiary: AppColors.accent,
      surface: AppColors.surfaceDark,
      // background: AppColors.backgroundDark, // Mapped via scaffoldBackgroundColor
      error: AppColors.error,
      onSurface: AppColors.textDark,
    ),

    // Scaffold & Background
    scaffoldBackgroundColor: AppColors.backgroundDark,
    cardColor: AppColors.surfaceElevatedDark,

    // Text Theme
    textTheme: GoogleFonts.nunitoTextTheme(
      ThemeData.dark().textTheme,
    ).apply(bodyColor: AppColors.textDark, displayColor: AppColors.textDark),

    // Component Styles
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      iconTheme: IconThemeData(color: AppColors.textDark),
      titleTextStyle: TextStyle(
        color: AppColors.textDark,
        fontSize: 20,
        fontWeight: FontWeight.bold,
        fontFamily: 'Nunito',
      ),
    ),

    iconTheme: const IconThemeData(color: AppColors.textDark),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 2,
      ),
    ),
  );
}
