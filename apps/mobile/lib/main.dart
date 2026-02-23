import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:app_links/app_links.dart';

import 'providers/auth_provider.dart';
import 'providers/download_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/navigation_provider.dart';
import 'providers/connectivity_provider.dart';
import 'providers/resources_provider.dart';
import 'providers/ai_tutor_history_provider.dart';
import 'router.dart' as app_router;

import 'screens/home_screen.dart';
import 'screens/landing_page.dart';
import 'screens/subscription/subscription_screen.dart';
import 'screens/auth/email_verification_screen.dart';
import 'screens/auth/auth_screen.dart';

import 'firebase_options.dart';
import 'services/notification_service.dart';
import 'services/offline_service.dart';
import 'services/update_service.dart';
import 'services/analytics_service.dart';
import 'config/app_theme.dart';
import 'widgets/app_error_widget.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  debugPrint('[TOPSCORE] 1. Starting main()');
  WidgetsFlutterBinding.ensureInitialized();

  // Enable clean URLs for web (removes # from URLs)
  usePathUrlStrategy();
  debugPrint(
    '[TOPSCORE] 2. WidgetsFlutterBinding initialized & URL strategy set',
  );

  // Load environment variables with error handling
  try {
    debugPrint('[TOPSCORE] 3. Loading dotenv...');
    // On web, dotenv loading might fail, but we don't need it since Firebase config is hardcoded
    if (!kIsWeb) {
      await dotenv.load(fileName: ".env");
    }
    debugPrint('[TOPSCORE] 4. Dotenv loaded successfully');
  } catch (e) {
    debugPrint('[TOPSCORE] 4. Dotenv load error (continuing anyway): $e');
  }

  // Initialize Firebase with error handling
  try {
    debugPrint('[TOPSCORE] 5. Checking Firebase apps...');
    if (Firebase.apps.isEmpty) {
      debugPrint('[TOPSCORE] 6. Initializing Firebase...');
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      debugPrint('[TOPSCORE] 7. Firebase initialized successfully');

      // Initialize Analytics
      AnalyticsService.instance.enableDebugMode();
      debugPrint('[TOPSCORE] 7b. Analytics initialized');
    } else {
      debugPrint('[TOPSCORE] 6-7. Firebase already initialized');
    }
  } catch (e, stackTrace) {
    debugPrint('[TOPSCORE] 7. Firebase init error: $e');
    debugPrint('[TOPSCORE] 7. Stack trace: $stackTrace');
  }

  // Enable offline persistence (only on non-web)
  if (!kIsWeb) {
    try {
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
      );
    } catch (e) {
      debugPrint("Firestore persistence error: $e");
    }
  }
  debugPrint('[TOPSCORE] 8. Firestore settings done (skipped on web)');

  // Init Notifications (skip on web to avoid blocking)
  if (!kIsWeb) {
    try {
      final notificationService = NotificationService();
      await notificationService.initialize();
      await setupInteractedMessage();
    } catch (e) {
      debugPrint("Notification Init Error: $e");
    }
  }
  debugPrint('[TOPSCORE] 9. Notifications done (skipped on web)');

  // Init Offline Storage (Initializes SharedPreferences on web, Hive on mobile)
  try {
    await OfflineService().init();
  } catch (e) {
    debugPrint("Offline Init Error: $e");
  }
  debugPrint('[TOPSCORE] 10. Offline storage done');

  debugPrint('[TOPSCORE] 11. Calling runApp()...');

  // Global error handler for uncaught Flutter widget errors
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('[TOPSCORE] FlutterError: ${details.exceptionAsString()}');
  };
  ErrorWidget.builder =
      (FlutterErrorDetails details) => AppErrorWidget(details: details);

  runApp(const MyApp());
  debugPrint('[TOPSCORE] 12. runApp() called');
}

Future<void> setupInteractedMessage() async {
  RemoteMessage? initialMessage =
      await FirebaseMessaging.instance.getInitialMessage();
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

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final AuthProvider _authProvider;
  late final DownloadProvider _downloadProvider;
  late final SettingsProvider _settingsProvider;
  late final NavigationProvider _navigationProvider;
  late final ConnectivityProvider _connectivityProvider;
  late final ResourcesProvider _resourcesProvider;
  late final AiTutorHistoryProvider _aiTutorHistoryProvider;
  late final AppLinks _appLinks;

  @override
  void initState() {
    super.initState();
    _authProvider = AuthProvider();
    _downloadProvider = DownloadProvider();
    _settingsProvider = SettingsProvider();
    _navigationProvider = NavigationProvider();
    _connectivityProvider = ConnectivityProvider();
    _resourcesProvider = ResourcesProvider();
    _aiTutorHistoryProvider = AiTutorHistoryProvider();

    if (kIsWeb) {
      UpdateService().startAutoCheck();
    }

    // Initialize deep link handling for app shortcuts
    if (!kIsWeb) {
      _appLinks = AppLinks();
      _initDeepLinks();
    }

    // Defer initialization until after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _authProvider.init();
      _downloadProvider.init();
      _navigationProvider.init();
      _resourcesProvider.loadRecentlyOpened();

      // Set analytics user properties once auth resolves
      _authProvider.addListener(_syncAnalyticsUser);
    });
  }

  void _syncAnalyticsUser() {
    final user = _authProvider.userModel;
    if (user != null) {
      AnalyticsService.instance.setUserId(user.uid);
      AnalyticsService.instance.setUserRole(user.role);

      // Also fetch AI Tutor history when auth resolves
      _aiTutorHistoryProvider.fetchHistory(user.uid);
    }
  }

  Future<void> _initDeepLinks() async {
    // Handle initial link (app opened from shortcut while closed)
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleDeepLink(initialUri);
      }
    } catch (e) {
      debugPrint('Error getting initial deep link: $e');
    }

    // Handle links while app is running
    _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    });
  }

  void _handleDeepLink(Uri uri) {
    // Convert topscore://app/path to /path for go_router
    if (uri.scheme == 'topscore' && uri.host == 'app') {
      final path = uri.path.isEmpty ? '/home' : uri.path;
      debugPrint('Deep link received: $path');
      // Navigate after a small delay to ensure router is ready
      Future.delayed(const Duration(milliseconds: 100), () {
        app_router.router.go(path);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: _authProvider),
        ChangeNotifierProvider<DownloadProvider>.value(
          value: _downloadProvider,
        ),
        ChangeNotifierProvider<SettingsProvider>.value(
          value: _settingsProvider,
        ),
        ChangeNotifierProvider<NavigationProvider>.value(
          value: _navigationProvider,
        ),
        ChangeNotifierProvider<ConnectivityProvider>.value(
          value: _connectivityProvider,
        ),
        ChangeNotifierProvider<ResourcesProvider>.value(
          value: _resourcesProvider,
        ),
        ChangeNotifierProvider<AiTutorHistoryProvider>.value(
          value: _aiTutorHistoryProvider,
        ),
      ],
      child: Consumer<AuthProvider>(
        builder: (context, authProvider, _) {
          return Consumer<SettingsProvider>(
            builder: (context, settings, _) {
              // Check if user is logged in or guest to decide routing strategy
              final isLoggedIn =
                  authProvider.userModel != null || authProvider.isGuest;

              if (isLoggedIn && !authProvider.needsRoleSelection) {
                // Use go_router for logged-in users/guests with clean URLs
                return MaterialApp.router(
                  title: 'TopScore AI',
                  debugShowCheckedModeBanner: false,
                  theme: AppTheme.lightTheme,
                  darkTheme: AppTheme.darkTheme,
                  themeMode: settings.themeMode,
                  locale: settings.locale,
                  supportedLocales: const [
                    Locale('en'),
                    Locale('sw'),
                  ],
                  routerConfig: app_router.router,
                );
              }

              return MaterialApp(
                title: 'TopScore AI',
                navigatorKey: navigatorKey,
                debugShowCheckedModeBanner: false,
                theme: AppTheme.lightTheme,
                darkTheme: AppTheme.darkTheme,
                themeMode: settings.themeMode,
                locale: settings.locale,
                navigatorObservers: [
                  AnalyticsService.instance.observer,
                ],
                supportedLocales: const [
                  Locale('en'),
                  Locale('sw'),
                ],
                home: const AuthWrapper(),
                routes: {
                  '/landing': (context) => const LandingPage(),
                  '/home': (context) => const HomeScreen(),
                },
              );
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

    if (authProvider.requiresEmailVerification) {
      return const EmailVerificationScreen();
    }

    if (authProvider.userModel == null) {
      return const AuthScreen();
    }

    // Always route to student home screen - teacher and parent screens disabled
    return const HomeScreen();
  }
}
