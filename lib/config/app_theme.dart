import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/colors.dart';

class AppTheme {
  // Spacing constants
  static const double spacingXs = 4.0;
  static const double spacingSm = 8.0;
  static const double spacingMd = 16.0;
  static const double spacingLg = 24.0;
  static const double spacingXl = 32.0;
  static const double spacing2xl = 48.0;

  // Border radius constants - Larger, more tactile for child-friendly UI
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 20.0;
  static const double radiusXl = 32.0;
  static const double radiusFull = 999.0;

  // Elevation constants
  static const double elevationSm = 2.0;
  static const double elevationMd = 4.0;
  static const double elevationLg = 8.0;
  static const double elevationXl = 16.0;

  // Animation durations
  static const Duration durationFast = Duration(milliseconds: 200);
  static const Duration durationNormal = Duration(milliseconds: 300);
  static const Duration durationSlow = Duration(milliseconds: 500);

  // --- LIGHT THEME ---
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    fontFamily: 'UniversalSans',

    // Color Scheme: Maps AppColors to Material Slots
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      tertiary: AppColors.accent,
      surface: AppColors.surface,
      error: AppColors.error,
    ),

    // Scaffold & Background
    scaffoldBackgroundColor: AppColors.background,
    cardColor: AppColors.surface,

    // Text Theme (UniversalSans)
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        fontFamily: 'UniversalSans',
        fontWeight: FontWeight.w500,
      ),
      displayMedium: TextStyle(
        fontFamily: 'UniversalSans',
        fontWeight: FontWeight.w500,
      ),
      displaySmall: TextStyle(
        fontFamily: 'UniversalSans',
        fontWeight: FontWeight.w500,
      ),
      headlineLarge: TextStyle(
        fontFamily: 'UniversalSans',
        fontWeight: FontWeight.w500,
      ),
      headlineMedium: TextStyle(
        fontFamily: 'UniversalSans',
        fontWeight: FontWeight.w500,
      ),
      headlineSmall: TextStyle(
        fontFamily: 'UniversalSans',
        fontWeight: FontWeight.w500,
      ),
      titleLarge: TextStyle(
        fontFamily: 'UniversalSans',
        fontWeight: FontWeight.w500,
      ),
      titleMedium: TextStyle(
        fontFamily: 'UniversalSans',
        fontWeight: FontWeight.w500,
      ),
      titleSmall: TextStyle(
        fontFamily: 'UniversalSans',
        fontWeight: FontWeight.w500,
      ),
      bodyLarge: TextStyle(
        fontFamily: 'UniversalSans',
        fontWeight: FontWeight.w500,
      ),
      bodyMedium: TextStyle(
        fontFamily: 'UniversalSans',
        fontWeight: FontWeight.w500,
      ),
      bodySmall: TextStyle(
        fontFamily: 'UniversalSans',
        fontWeight: FontWeight.w500,
      ),
      labelLarge: TextStyle(
        fontFamily: 'UniversalSans',
        fontWeight: FontWeight.w500,
      ),
      labelMedium: TextStyle(
        fontFamily: 'UniversalSans',
        fontWeight: FontWeight.w500,
      ),
      labelSmall: TextStyle(
        fontFamily: 'UniversalSans',
        fontWeight: FontWeight.w500,
      ),
    ).apply(bodyColor: AppColors.text, displayColor: AppColors.text),

    // Component Styles
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      iconTheme: const IconThemeData(color: AppColors.text),
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      titleTextStyle: const TextStyle(
        fontFamily: 'UniversalSans',
        color: AppColors.text,
        fontSize: 20,
        fontWeight: FontWeight.w500,
      ),
    ),

    iconTheme: const IconThemeData(color: AppColors.text),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
        elevation: 0,
        padding: const EdgeInsets.symmetric(
          horizontal: spacingLg,
          vertical: spacingMd,
        ),
        minimumSize: const Size(120, 48),
        textStyle: const TextStyle(
          fontFamily: 'UniversalSans',
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        padding: const EdgeInsets.symmetric(
          horizontal: spacingMd,
          vertical: spacingSm,
        ),
        textStyle: const TextStyle(
          fontFamily: 'UniversalSans',
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primary, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: spacingLg,
          vertical: spacingMd,
        ),
        minimumSize: const Size(120, 48),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: const BorderSide(color: AppColors.border, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: const BorderSide(color: AppColors.border, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: spacingMd,
        vertical: spacingMd,
      ),
    ),

    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusLg),
        side: const BorderSide(color: AppColors.border, width: 0.5),
      ),
      color: AppColors.surface,
      margin: const EdgeInsets.all(spacingSm),
    ),

    chipTheme: ChipThemeData(
      backgroundColor: AppColors.surfaceVariant,
      labelStyle: const TextStyle(
        fontFamily: 'UniversalSans',
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: spacingMd,
        vertical: spacingSm,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusFull),
      ),
    ),

    dividerTheme: const DividerThemeData(
      color: AppColors.border,
      thickness: 1,
      space: spacingMd,
    ),

    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.primaryDark,
      contentTextStyle: const TextStyle(
        fontFamily: 'UniversalSans',
        color: Colors.white,
        fontSize: 14,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusMd),
      ),
      behavior: SnackBarBehavior.floating,
    ),

    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.surface,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.textSecondary,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),

    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusLg),
      ),
    ),

    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.primary,
      linearTrackColor: AppColors.surfaceVariant,
    ),

    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return AppColors.primary;
        return AppColors.textSecondary;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.primary.withValues(alpha: 0.5);
        }
        return AppColors.surfaceVariant;
      }),
    ),
  );

  // --- DARK THEME ---
  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: 'UniversalSans',

    // Color Scheme
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.dark,
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      tertiary: AppColors.accent,
      surface: AppColors.surfaceDark,
      error: AppColors.error,
      onSurface: AppColors.textDark,
    ),

    // Scaffold & Background
    scaffoldBackgroundColor: AppColors.backgroundDark,
    cardColor: AppColors.surfaceElevatedDark,

    // Text Theme
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        fontFamily: 'UniversalSans',
        fontWeight: FontWeight.w500,
      ),
      displayMedium: TextStyle(
        fontFamily: 'UniversalSans',
        fontWeight: FontWeight.w500,
      ),
      displaySmall: TextStyle(
        fontFamily: 'UniversalSans',
        fontWeight: FontWeight.w500,
      ),
      headlineLarge: TextStyle(
        fontFamily: 'UniversalSans',
        fontWeight: FontWeight.w500,
      ),
      headlineMedium: TextStyle(
        fontFamily: 'UniversalSans',
        fontWeight: FontWeight.w500,
      ),
      headlineSmall: TextStyle(
        fontFamily: 'UniversalSans',
        fontWeight: FontWeight.w500,
      ),
      titleLarge: TextStyle(
        fontFamily: 'UniversalSans',
        fontWeight: FontWeight.w500,
      ),
      titleMedium: TextStyle(
        fontFamily: 'UniversalSans',
        fontWeight: FontWeight.w500,
      ),
      titleSmall: TextStyle(
        fontFamily: 'UniversalSans',
        fontWeight: FontWeight.w500,
      ),
      bodyLarge: TextStyle(
        fontFamily: 'UniversalSans',
        fontWeight: FontWeight.w500,
      ),
      bodyMedium: TextStyle(
        fontFamily: 'UniversalSans',
        fontWeight: FontWeight.w500,
      ),
      bodySmall: TextStyle(
        fontFamily: 'UniversalSans',
        fontWeight: FontWeight.w500,
      ),
      labelLarge: TextStyle(
        fontFamily: 'UniversalSans',
        fontWeight: FontWeight.w500,
      ),
      labelMedium: TextStyle(
        fontFamily: 'UniversalSans',
        fontWeight: FontWeight.w500,
      ),
      labelSmall: TextStyle(
        fontFamily: 'UniversalSans',
        fontWeight: FontWeight.w500,
      ),
    ).apply(bodyColor: AppColors.textDark, displayColor: AppColors.textDark),

    // Component Styles
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      iconTheme: const IconThemeData(color: AppColors.textDark),
      systemOverlayStyle: SystemUiOverlayStyle.light,
      titleTextStyle: const TextStyle(
        fontFamily: 'UniversalSans',
        color: AppColors.textDark,
        fontSize: 20,
        fontWeight: FontWeight.w500,
      ),
    ),

    iconTheme: const IconThemeData(color: AppColors.textDark),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
        elevation: 0,
        padding: const EdgeInsets.symmetric(
          horizontal: spacingLg,
          vertical: spacingMd,
        ),
        minimumSize: const Size(120, 48),
        textStyle: const TextStyle(
          fontFamily: 'UniversalSans',
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.accentTeal,
        padding: const EdgeInsets.symmetric(
          horizontal: spacingMd,
          vertical: spacingSm,
        ),
        textStyle: const TextStyle(
          fontFamily: 'UniversalSans',
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.accentTeal,
        side: const BorderSide(color: AppColors.accentTeal, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: spacingLg,
          vertical: spacingMd,
        ),
        minimumSize: const Size(120, 48),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceElevatedDark,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: const BorderSide(color: AppColors.borderDark, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: const BorderSide(color: AppColors.borderDark, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: const BorderSide(color: AppColors.accentTeal, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: spacingMd,
        vertical: spacingMd,
      ),
    ),

    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusLg),
        side: const BorderSide(color: AppColors.borderDark, width: 0.5),
      ),
      color: AppColors.surfaceElevatedDark,
      margin: const EdgeInsets.all(spacingSm),
    ),

    chipTheme: ChipThemeData(
      backgroundColor: AppColors.surfaceVariantDark,
      labelStyle: const TextStyle(
        fontFamily: 'UniversalSans',
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppColors.textDark,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: spacingMd,
        vertical: spacingSm,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusFull),
      ),
    ),

    dividerTheme: const DividerThemeData(
      color: AppColors.borderDark,
      thickness: 1,
      space: spacingMd,
    ),

    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.surfaceElevatedDark,
      contentTextStyle: const TextStyle(
        fontFamily: 'UniversalSans',
        color: AppColors.textDark,
        fontSize: 14,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusMd),
      ),
      behavior: SnackBarBehavior.floating,
    ),

    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.surfaceDark,
      selectedItemColor: AppColors.accentTeal,
      unselectedItemColor: AppColors.textSecondaryDark,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),

    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: AppColors.accentTeal,
      foregroundColor: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusLg),
      ),
    ),

    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.accentTeal,
      linearTrackColor: AppColors.surfaceVariantDark,
    ),

    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return AppColors.accentTeal;
        return AppColors.textSecondaryDark;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.accentTeal.withValues(alpha: 0.5);
        }
        return AppColors.surfaceVariantDark;
      }),
    ),
  );

  // Helper methods for consistent shadows
  static List<BoxShadow> getShadow({
    double elevation = elevationMd,
    Color? color,
    bool isDark = false,
  }) {
    final shadowColor = color ?? (isDark ? Colors.black54 : Colors.black12);
    return [
      BoxShadow(
        color: shadowColor,
        blurRadius: elevation * 2,
        offset: Offset(0, elevation / 2),
        spreadRadius: 0,
      ),
    ];
  }

  static List<BoxShadow> getGlowShadow(Color color, {double intensity = 0.4}) {
    return [
      BoxShadow(
        color: color.withValues(alpha: intensity),
        blurRadius: 20,
        offset: const Offset(0, 8),
        spreadRadius: 0,
      ),
    ];
  }

  // --- NEW: Glass Container Helper ---
  static Widget buildGlassContainer(
    BuildContext context, {
    required Widget child,
    double blur = 12.0,
    double opacity = 0.05,
    double borderRadius = 16.0,
    double? width,
    double? height,
    BoxBorder? border,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: width,
      height: height,
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: (isDark ? Colors.white : Colors.white).withValues(
                alpha: opacity,
              ),
              borderRadius: BorderRadius.circular(borderRadius),
              border:
                  border ??
                  Border.all(
                    color: Colors.white.withValues(alpha: isDark ? 0.08 : 0.4),
                    width: 1.5,
                  ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
