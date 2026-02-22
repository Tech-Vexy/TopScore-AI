import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'services/analytics_service.dart';
import 'services/offline_service.dart';

// Screens
import 'screens/home_screen.dart';
import 'screens/student/resources_screen.dart';
// Teacher screens removed for unified learner experience
import 'screens/tools/tools_screen.dart';
import 'screens/profile_screen.dart' as profile_page;
import 'screens/pdf_viewer_screen.dart';

// Deferred imports for heavy screens (code splitting)
import 'tutor_client/chat_screen.dart' deferred as chat;
import 'screens/tools/periodic_table_screen.dart' deferred as periodic_table;
import 'screens/tools/science_lab_screen.dart' deferred as science_lab;
import 'screens/tools/flashcard_generator_screen.dart' deferred as flashcards;

// Tool Sub-screens (lightweight - no deferred loading)
import 'screens/tools/calculator_screen.dart';
import 'screens/tools/smart_scanner_screen.dart';
import 'screens/tools/timetable_screen.dart';
import 'screens/search_screen.dart';
import 'screens/auth/onboarding_screen.dart';
import 'screens/student/career_compass_screen.dart';

// Widget that holds the BottomNavigationBar
import 'widgets/scaffold_with_navbar.dart';

// Deferred loading widget for consistent UX
class _DeferredLoadingScreen extends StatelessWidget {
  final String message;
  const _DeferredLoadingScreen({this.message = 'Loading...'});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(message, style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }
}

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

final GoRouter router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/home', // Default start tab
  // Ensure URLs are properly handled
  debugLogDiagnostics: false,
  observers: [AnalyticsService.instance.observer],
  routes: [
    // This "Shell" handles the Bottom Navigation Bar logic
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return ScaffoldWithNavBar(navigationShell: navigationShell);
      },
      branches: [
        // Tab 1: Home
        StatefulShellBranch(
          // Add navigator key for proper state management
          navigatorKey: GlobalKey<NavigatorState>(debugLabel: 'homeShell'),
          routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => const HomeTab(),
            ),
          ],
        ),
        // Tab 2: Library
        StatefulShellBranch(
          navigatorKey: GlobalKey<NavigatorState>(debugLabel: 'libraryShell'),
          routes: [
            GoRoute(
              path: '/library',
              builder: (context, state) => const ResourcesScreen(),
            ),
          ],
        ),
        // Tab 3: AI Tutor
        StatefulShellBranch(
          navigatorKey: GlobalKey<NavigatorState>(debugLabel: 'tutorShell'),
          routes: [
            GoRoute(
              path: '/ai-tutor',
              pageBuilder: (context, state) => NoTransitionPage(
                child: FutureBuilder(
                  future: chat.loadLibrary(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.done) {
                      return chat.ChatScreen();
                    }
                    return const _DeferredLoadingScreen(
                        message: 'Starting AI Tutor...');
                  },
                ),
              ),
            ),
          ],
        ),
        // Tab 4: Tools (With sub-routes!)
        StatefulShellBranch(
          navigatorKey: GlobalKey<NavigatorState>(debugLabel: 'toolsShell'),
          routes: [
            GoRoute(
              path: '/tools',
              builder: (context, state) => const ToolsScreen(),
              routes: [
                // Sub-routes for tools so URL becomes /tools/calculator
                GoRoute(
                  path: 'calculator',
                  builder: (context, state) => const CalculatorScreen(),
                ),
                GoRoute(
                  path: 'scanner',
                  builder: (context, state) => const SmartScannerScreen(),
                ),
                GoRoute(
                  path: 'flashcards',
                  pageBuilder: (context, state) => NoTransitionPage(
                    child: FutureBuilder(
                      future: flashcards.loadLibrary(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.done) {
                          return flashcards.FlashcardGeneratorScreen();
                        }
                        return const _DeferredLoadingScreen(
                            message: 'Loading Flashcards...');
                      },
                    ),
                  ),
                ),
                GoRoute(
                  path: 'timetable',
                  builder: (context, state) => const TimetableScreen(),
                ),
                GoRoute(
                  path: 'science_lab',
                  pageBuilder: (context, state) => NoTransitionPage(
                    child: FutureBuilder(
                      future: science_lab.loadLibrary(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.done) {
                          return science_lab.ScienceLabScreen();
                        }
                        return const _DeferredLoadingScreen(
                            message: 'Loading Science Lab...');
                      },
                    ),
                  ),
                ),
                GoRoute(
                  path: 'periodic_table',
                  pageBuilder: (context, state) => NoTransitionPage(
                    child: FutureBuilder(
                      future: periodic_table.loadLibrary(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.done) {
                          return periodic_table.PeriodicTableScreen();
                        }
                        return const _DeferredLoadingScreen(
                            message: 'Loading Periodic Table...');
                      },
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        // Tab 5: Profile
        StatefulShellBranch(
          navigatorKey: GlobalKey<NavigatorState>(debugLabel: 'profileShell'),
          routes: [
            GoRoute(
              path: '/profile',
              builder: (context, state) => const profile_page.ProfileScreen(),
            ),
          ],
        ),
      ],
    ),
    // Search
    GoRoute(
      path: '/search',
      builder: (context, state) => const SearchScreen(),
    ),
    // Onboarding
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
    // Career Compass
    GoRoute(
      path: '/career-compass',
      builder: (context, state) => const CareerCompassScreen(),
    ),
    // PDF Viewer
    GoRoute(
      path: '/pdf-viewer',
      pageBuilder: (context, state) {
        final extras = state.extra as Map<String, dynamic>? ?? {};
        return CustomTransitionPage(
          key: state.pageKey,
          child: PdfViewerScreen(
            url: extras['url'],
            storagePath: extras['storagePath'],
            assetPath: extras['assetPath'],
            bytes: extras['bytes'],
            file: extras['file'],
            title: extras['title'] ?? 'Document',
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        );
      },
    ),
  ],
  redirect: (context, state) {
    // Check if onboarding is complete
    final onboardingComplete =
        OfflineService().getStringList('onboarding_complete').isNotEmpty;

    // If trying to access home/library/tutor/tools and onboarding isn't done
    const protectedRoutes = [
      '/home',
      '/library',
      '/ai-tutor',
      '/tools',
      '/profile'
    ];
    if (!onboardingComplete &&
        protectedRoutes
            .any((route) => state.fullPath?.startsWith(route) ?? false)) {
      return '/onboarding';
    }

    return null;
  },
);
