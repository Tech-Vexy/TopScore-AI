import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// Screens
import 'screens/home_screen.dart';
import 'screens/student/resources_screen.dart'; // Uses the flat specific library screen
import 'tutor_client/chat_screen.dart';
import 'screens/tools/tools_screen.dart';
import 'screens/support/support_screen.dart';

// Tool Sub-screens
import 'screens/tools/calculator_screen.dart';
import 'screens/tools/smart_scanner_screen.dart';
import 'screens/tools/flashcard_generator_screen.dart';
import 'screens/tools/timetable_screen.dart';
import 'screens/tools/science_lab_screen.dart';
import 'screens/tools/periodic_table_screen.dart';

// Widget that holds the BottomNavigationBar
import 'widgets/scaffold_with_navbar.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

final GoRouter router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/home', // Default start tab
  routes: [
    // This "Shell" handles the Bottom Navigation Bar logic
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return ScaffoldWithNavBar(navigationShell: navigationShell);
      },
      branches: [
        // Tab 1: Home
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => const HomeTab(),
            ),
          ],
        ),
        // Tab 2: Library
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/library',
              builder: (context, state) =>
                  const ResourcesScreen(), // Use correct class
            ),
          ],
        ),
        // Tab 3: AI Tutor
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/ai-tutor',
              builder: (context, state) => const ChatScreen(),
            ),
          ],
        ),
        // Tab 4: Tools (With sub-routes!)
        StatefulShellBranch(
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
                  builder: (context, state) => const FlashcardGeneratorScreen(),
                ),
                GoRoute(
                  path: 'timetable',
                  builder: (context, state) => const TimetableScreen(),
                ),
                GoRoute(
                  path: 'science_lab',
                  builder: (context, state) => const ScienceLabScreen(),
                ),
                GoRoute(
                  path: 'periodic_table',
                  builder: (context, state) => const PeriodicTableScreen(),
                ),
              ],
            ),
          ],
        ),
        // Tab 5: Support
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/support',
              builder: (context, state) => const SupportScreen(),
            ),
          ],
        ),
      ],
    ),
  ],
);
