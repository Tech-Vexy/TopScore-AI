import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'providers/auth_provider.dart';
import 'providers/resource_provider.dart';
import 'providers/download_provider.dart';
import 'screens/auth/auth_screen.dart';
import 'screens/auth/role_selection_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/landing_page.dart';
import 'constants/colors.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

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
        builder: (context, child) {
          final mediaQuery = MediaQuery.of(context);
          // If screen is wider than 500px, constrain it to mobile size
          if (mediaQuery.size.width > 500) {
            return Container(
              color: const Color(0xFFF0F2F5),
              alignment: Alignment.center,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: MediaQuery(
                  data: mediaQuery.copyWith(
                    size: Size(500, mediaQuery.size.height),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                    child: child,
                  ),
                ),
              ),
            );
          }
          return child!;
        },
        theme: ThemeData(
          primaryColor: AppColors.primary,
          scaffoldBackgroundColor: AppColors.background,
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.primary,
            secondary: AppColors.secondary,
            surface: AppColors.surface,
            onSurface: AppColors.text,
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          textTheme: GoogleFonts.outfitTextTheme(),
          appBarTheme: AppBarTheme(
            backgroundColor: AppColors.surface,
            elevation: 0,
            centerTitle: true,
            titleTextStyle: GoogleFonts.outfit(
              color: AppColors.text,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            iconTheme: const IconThemeData(color: AppColors.text),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.white,
              elevation: 2,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.textLight),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.textLight),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
        darkTheme: ThemeData(
          primaryColor: AppColors.primary,
          scaffoldBackgroundColor: AppColors.backgroundDark,
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.primary,
            secondary: AppColors.secondary,
            surface: AppColors.surfaceDark,
            onSurface: AppColors.textDark,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
          textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
          appBarTheme: AppBarTheme(
            backgroundColor: AppColors.surfaceDark,
            elevation: 0,
            centerTitle: true,
            titleTextStyle: GoogleFonts.outfit(
              color: AppColors.textDark,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            iconTheme: const IconThemeData(color: AppColors.textDark),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.white,
              elevation: 2,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: AppColors.surfaceVariantDark,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.textSecondaryDark),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.textSecondaryDark),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            labelStyle: const TextStyle(color: AppColors.textSecondaryDark),
            hintStyle: const TextStyle(color: AppColors.textSecondaryDark),
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
        print("=== AuthWrapper Debug ===");
        print("isLoading: ${authProvider.isLoading}");
        print("needsRoleSelection: ${authProvider.needsRoleSelection}");
        print("userModel: ${authProvider.userModel}");
        print("========================");

        if (authProvider.isLoading) {
          print("Rendering loading screen");
          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: AppColors.primary),
                  const SizedBox(height: 20),
                  Text(
                    "Loading...", 
                    style: TextStyle(
                      fontSize: 18, 
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        if (authProvider.needsRoleSelection) {
          print("Rendering role selection screen");
          return const RoleSelectionScreen();
        }

        if (authProvider.userModel != null) {
          print("Rendering dashboard for user: ${authProvider.userModel!.displayName}");
          // Enhanced dashboard preview
          return const DashboardScreen();
        }

        print("Rendering landing page");
        return const LandingPage();
      },
    );
  }
}
