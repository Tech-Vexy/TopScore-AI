import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
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
  
  // Load environment variables
  await dotenv.load(fileName: ".env");
  
  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Enable offline persistence
  try {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
    );
  } catch (e) {
    debugPrint("Firestore persistence error: $e");
  }

  runApp(MyApp());
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
        themeMode: ThemeMode.system,
        
        // Light Theme
        theme: ThemeData.light().copyWith(
          scaffoldBackgroundColor: Colors.white,
          cardColor: const Color(0xFFF0F4F9),
          colorScheme: ColorScheme.light(
            primary: AppColors.primary,
            secondary: AppColors.secondary,
            surface: const Color(0xFFF0F4F9),
            onSurface: Colors.black87,
            primaryContainer: const Color(0xFFE1E5EA),
          ),
          iconTheme: const IconThemeData(color: Colors.black54),
        ),

        // Dark Theme
        darkTheme: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: const Color(0xFF131314),
          cardColor: const Color(0xFF1E1F20),
          colorScheme: ColorScheme.dark(
            primary: AppColors.accentTeal,
            secondary: AppColors.secondaryViolet,
            surface: const Color(0xFF1E1F20),
            onSurface: Colors.white,
            primaryContainer: const Color(0xFF28292A),
          ),
          iconTheme: const IconThemeData(color: Colors.white70),
        ),
        
        // Center content with max width constraint
        builder: (context, child) {
          final mediaQuery = MediaQuery.of(context);
          final screenWidth = mediaQuery.size.width;
          const maxContentWidth = 1200.0;

          if (screenWidth > maxContentWidth) {
            return Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: Center(
                child: Container(
                  width: maxContentWidth,
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).brightness == Brightness.dark 
                            ? Colors.black.withValues(alpha: 0.3) 
                            : AppColors.primaryPurple.withValues(alpha: 0.08),
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
