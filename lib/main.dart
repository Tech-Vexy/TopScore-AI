import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'providers/auth_provider.dart';
import 'providers/resource_provider.dart';
import 'providers/download_provider.dart';
import 'screens/auth/role_selection_screen.dart';
import 'screens/home_screen.dart';
import 'screens/landing_page.dart';
import 'constants/colors.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Enable offline persistence
  try {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
    );
  } catch (e) {
    debugPrint("Firestore persistence error: $e");
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..init()),
        ChangeNotifierProvider(create: (_) => ResourceProvider()),
        ChangeNotifierProvider(create: (_) => DownloadProvider()..init()),
      ],
      child: MaterialApp(
        title: 'TopScore AI',
        debugShowCheckedModeBanner: false,
        // Center content with max width constraint (similar to kcserevision.com)
        builder: (context, child) {
          final mediaQuery = MediaQuery.of(context);
          final screenWidth = mediaQuery.size.width;
          const maxContentWidth = 1200.0; // Similar to kcserevision.com

          // On wider screens, center the content with constrained width
          if (screenWidth > maxContentWidth) {
            return Container(
              color: AppColors.background,
              child: Center(
                child: Container(
                  width: maxContentWidth,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryPurple.withValues(alpha: 0.08),
                        blurRadius: 40,
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: child,
                ),
              ),
            );
          }
          return child!;
        },
        // Light Theme (EduPoa-inspired)
        theme: ThemeData(
          primaryColor: AppColors.primary,
          scaffoldBackgroundColor: AppColors.background,
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.primary,
            primary: AppColors.primary,
            secondary: AppColors.secondary,
            surface: AppColors.surface,
            onSurface: AppColors.text,
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          // Use Poppins font throughout the app
          textTheme: GoogleFonts.poppinsTextTheme().copyWith(
            displayLarge: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              color: AppColors.text,
            ),
            displayMedium: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              color: AppColors.text,
            ),
            displaySmall: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              color: AppColors.text,
            ),
            headlineLarge: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              color: AppColors.text,
            ),
            headlineMedium: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
            headlineSmall: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
            titleLarge: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
            titleMedium: GoogleFonts.poppins(
              fontWeight: FontWeight.w500,
              color: AppColors.text,
            ),
            titleSmall: GoogleFonts.poppins(
              fontWeight: FontWeight.w500,
              color: AppColors.text,
            ),
            bodyLarge: GoogleFonts.poppins(
              fontWeight: FontWeight.normal,
              color: AppColors.text,
            ),
            bodyMedium: GoogleFonts.poppins(
              fontWeight: FontWeight.normal,
              color: AppColors.text,
            ),
            bodySmall: GoogleFonts.poppins(
              fontWeight: FontWeight.normal,
              color: AppColors.textSecondary,
            ),
            labelLarge: GoogleFonts.poppins(
              fontWeight: FontWeight.w500,
              color: AppColors.text,
            ),
            labelMedium: GoogleFonts.poppins(
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
            labelSmall: GoogleFonts.poppins(
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          appBarTheme: AppBarTheme(
            backgroundColor: AppColors.surface,
            elevation: 0,
            scrolledUnderElevation: 1,
            centerTitle: true,
            titleTextStyle: GoogleFonts.poppins(
              color: AppColors.text,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            iconTheme: const IconThemeData(color: AppColors.primary),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentTeal,
              foregroundColor: AppColors.white,
              elevation: 0,
              shadowColor: AppColors.accentTeal.withValues(alpha: 0.3),
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              side: const BorderSide(color: AppColors.primary, width: 1.5),
              textStyle: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              foregroundColor: AppColors.accentTeal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              textStyle: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: AppColors.surfaceVariant,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppColors.accentTeal,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.error, width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.error, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 18,
            ),
            hintStyle: GoogleFonts.poppins(
              color: AppColors.textLight,
              fontSize: 14,
            ),
            labelStyle: GoogleFonts.poppins(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          cardTheme: CardThemeData(
            color: AppColors.surface,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            shadowColor: Colors.black.withValues(alpha: 0.05),
          ),
          chipTheme: ChipThemeData(
            backgroundColor: AppColors.surfaceVariant,
            selectedColor: AppColors.accentTeal.withValues(alpha: 0.2),
            labelStyle: GoogleFonts.poppins(fontSize: 13),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          bottomNavigationBarTheme: const BottomNavigationBarThemeData(
            backgroundColor: AppColors.surface,
            selectedItemColor: AppColors.accentTeal,
            unselectedItemColor: AppColors.textLight,
          ),
          floatingActionButtonTheme: FloatingActionButtonThemeData(
            backgroundColor: AppColors.accentTeal,
            foregroundColor: AppColors.white,
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        // Dark Theme (EduPoa-inspired)
        darkTheme: ThemeData(
          primaryColor: AppColors.primary,
          scaffoldBackgroundColor: AppColors.backgroundDark,
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.primary,
            primary: AppColors.accentTeal,
            secondary: AppColors.secondaryViolet,
            surface: AppColors.surfaceDark,
            onSurface: AppColors.textDark,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
          textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme)
              .copyWith(
                displayLarge: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
                displayMedium: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
                displaySmall: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
                headlineLarge: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
                headlineMedium: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
                headlineSmall: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
                titleLarge: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
                titleMedium: GoogleFonts.poppins(
                  fontWeight: FontWeight.w500,
                  color: AppColors.textDark,
                ),
                bodyLarge: GoogleFonts.poppins(
                  fontWeight: FontWeight.normal,
                  color: AppColors.textDark,
                ),
                bodyMedium: GoogleFonts.poppins(
                  fontWeight: FontWeight.normal,
                  color: AppColors.textDark,
                ),
                bodySmall: GoogleFonts.poppins(
                  fontWeight: FontWeight.normal,
                  color: AppColors.textSecondaryDark,
                ),
              ),
          appBarTheme: AppBarTheme(
            backgroundColor: AppColors.surfaceDark,
            elevation: 0,
            scrolledUnderElevation: 1,
            centerTitle: true,
            titleTextStyle: GoogleFonts.poppins(
              color: AppColors.textDark,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            iconTheme: const IconThemeData(color: AppColors.accentTeal),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentTeal,
              foregroundColor: AppColors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.accentTeal,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              side: const BorderSide(color: AppColors.accentTeal, width: 1.5),
            ),
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              foregroundColor: AppColors.accentTeal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: AppColors.surfaceVariantDark,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppColors.accentTeal,
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 18,
            ),
            hintStyle: GoogleFonts.poppins(color: AppColors.textSecondaryDark),
            labelStyle: GoogleFonts.poppins(color: AppColors.textSecondaryDark),
          ),
          cardTheme: CardThemeData(
            color: AppColors.surfaceDark,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          bottomNavigationBarTheme: const BottomNavigationBarThemeData(
            backgroundColor: AppColors.surfaceDark,
            selectedItemColor: AppColors.accentTeal,
            unselectedItemColor: AppColors.textSecondaryDark,
          ),
          floatingActionButtonTheme: FloatingActionButtonThemeData(
            backgroundColor: AppColors.accentTeal,
            foregroundColor: AppColors.white,
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        themeMode: ThemeMode.system,
        home: const AuthWrapper(),
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        debugPrint("=== AuthWrapper Debug ===");
        debugPrint("isLoading: ${authProvider.isLoading}");
        debugPrint("needsRoleSelection: ${authProvider.needsRoleSelection}");
        debugPrint("userModel: ${authProvider.userModel}");
        debugPrint("========================");

        if (authProvider.isLoading) {
          debugPrint("Rendering loading screen");
          return Scaffold(
            body: Container(
              decoration: const BoxDecoration(gradient: AppColors.heroGradient),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Animated loading indicator
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const CircularProgressIndicator(
                        color: AppColors.accentTeal,
                        strokeWidth: 3,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      "Loading...",
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (authProvider.needsRoleSelection) {
          debugPrint("Rendering role selection screen");
          return const RoleSelectionScreen();
        }

        if (authProvider.userModel != null) {
          debugPrint(
            "Rendering home screen for user: ${authProvider.userModel!.displayName}",
          );
          return const HomeScreen();
        }

        debugPrint("Rendering landing page");
        return const LandingPage();
      },
    );
  }
}
