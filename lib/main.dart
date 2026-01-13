import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'providers/auth_provider.dart';
import 'providers/resource_provider.dart';
import 'providers/download_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/navigation_provider.dart';

import 'screens/auth/role_selection_screen.dart';
import 'screens/home_screen.dart';
import 'screens/landing_page.dart';
import 'screens/teacher/teacher_home_screen.dart';
import 'screens/parent/parent_home_screen.dart';
import 'screens/subscription/subscription_screen.dart';

import 'firebase_options.dart';
import 'services/notification_service.dart';
import 'services/offline_service.dart';
import 'config/app_theme.dart'; // <--- Import the new theme file

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: ".env");

  // Initialize Firebase
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  // Enable offline persistence
  try {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
    );
  } catch (e) {
    debugPrint("Firestore persistence error: $e");
  }

  // Init Notifications
  try {
    final notificationService = NotificationService();
    await notificationService.initialize();
    await setupInteractedMessage();
  } catch (e) {
    debugPrint("Notification Init Error: $e");
  }

  // Init Offline Storage
  try {
    await OfflineService().init();
  } catch (e) {
    debugPrint("Offline Init Error: $e");
  }

  runApp(const MyApp());
}

Future<void> setupInteractedMessage() async {
  RemoteMessage? initialMessage = await FirebaseMessaging.instance
      .getInitialMessage();
  if (initialMessage != null) {
    _handleMessage(initialMessage);
  }
  FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);
}

void _handleMessage(RemoteMessage message) {
  if (message.data['screen'] == 'subscription_page') {
    navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
    );
  } else if (message.data['screen'] == 'daily_challenge') {
    debugPrint("Daily Challenge Notification Clicked");
  }
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
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => NavigationProvider()),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          return MaterialApp(
            title: 'TopScore AI',
            navigatorKey: navigatorKey,
            debugShowCheckedModeBanner: false,

            // --- UNIFORM THEMING CONFIGURATION ---
            theme: AppTheme.lightTheme, // Use centralized Light Theme
            darkTheme: AppTheme.darkTheme, // Use centralized Dark Theme
            themeMode: settings.themeMode, // Respects System/User Preference

            home: const AuthWrapper(),
            routes: {
              '/landing': (context) => const LandingPage(),
              '/home': (context) => const HomeScreen(),
            },
          );
        },
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    if (authProvider.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (authProvider.userModel == null) {
      return const LandingPage();
    }

    if (authProvider.needsRoleSelection) {
      return const RoleSelectionScreen();
    }

    // Role-based routing
    final role = authProvider.userModel?.role;
    if (role == 'teacher') {
      return const TeacherHomeScreen();
    } else if (role == 'parent') {
      return const ParentHomeScreen();
    }

    return const HomeScreen();
  }
}
