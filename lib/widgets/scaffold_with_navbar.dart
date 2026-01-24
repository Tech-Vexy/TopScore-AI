import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../constants/colors.dart';

class ScaffoldWithNavBar extends StatelessWidget {
  const ScaffoldWithNavBar({required this.navigationShell, Key? key})
    : super(key: key ?? const ValueKey<String>('ScaffoldWithNavBar'));

  final StatefulNavigationShell navigationShell;

  void _goBranch(int index) {
    navigationShell.goBranch(
      index,
      // Always navigate to initial location to ensure deep links work correctly
      initialLocation: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.surfaceDark
              : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: _goBranch,
          backgroundColor: Colors.transparent,
          indicatorColor: AppColors.accentTeal.withValues(alpha: 0.2),
          elevation: 0,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(
              icon: FaIcon(FontAwesomeIcons.house, size: 20),
              label: 'Home',
            ),
            NavigationDestination(
              icon: FaIcon(FontAwesomeIcons.folderOpen, size: 20),
              label: 'Library',
            ),
            NavigationDestination(
              icon: FaIcon(FontAwesomeIcons.brain, size: 20),
              label: 'AI Tutor',
            ),
            NavigationDestination(
              icon: FaIcon(FontAwesomeIcons.briefcase, size: 20),
              label: 'Tools',
            ),
            NavigationDestination(
              icon: FaIcon(FontAwesomeIcons.user, size: 20),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
