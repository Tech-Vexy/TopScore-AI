import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../constants/colors.dart';
import 'network_aware_image.dart';

class ScaffoldWithNavBar extends StatefulWidget {
  const ScaffoldWithNavBar({required this.navigationShell, Key? key})
    : super(key: key ?? const ValueKey<String>('ScaffoldWithNavBar'));

  final StatefulNavigationShell navigationShell;

  @override
  State<ScaffoldWithNavBar> createState() => _ScaffoldWithNavBarState();
}

class _ScaffoldWithNavBarState extends State<ScaffoldWithNavBar> {
  bool _isCollapsed = false;

  void _goBranch(int index) {
    widget.navigationShell.goBranch(index, initialLocation: true);
  }

  void _toggleSidebar() {
    setState(() {
      _isCollapsed = !_isCollapsed;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = Provider.of<AuthProvider>(context).userModel;

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 768) {
          // Mobile: Bottom Navigation Bar
          return Scaffold(
            body: widget.navigationShell,
            bottomNavigationBar: Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: NavigationBar(
                selectedIndex: widget.navigationShell.currentIndex,
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
        } else {
          // Desktop: Left Sidebar
          return Scaffold(
            body: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  width: _isCollapsed ? 80 : 260,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceDark : Colors.white,
                    border: Border(
                      right: BorderSide(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.black.withValues(alpha: 0.05),
                      ),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Logo Header
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: _isCollapsed ? 12 : 24,
                          vertical: 24,
                        ),
                        alignment: Alignment.centerLeft,
                        child: Row(
                          mainAxisAlignment: _isCollapsed
                              ? MainAxisAlignment.center
                              : MainAxisAlignment.start,
                          children: [
                            if (!_isCollapsed) ...[
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.accentTeal.withValues(
                                    alpha: 0.1,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: Image.asset(
                                  'assets/images/logo.png',
                                  width: 24,
                                  height: 24,
                                  fit: BoxFit.contain,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'TopScore AI',
                                  style: GoogleFonts.outfit(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                            IconButton(
                              icon: Icon(
                                _isCollapsed
                                    ? Icons.chevron_right
                                    : Icons.chevron_left,
                                size: 20,
                                color: Colors.grey,
                              ),
                              onPressed: _toggleSidebar,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Navigation Items
                      _SidebarItem(
                        icon: FontAwesomeIcons.house,
                        label: 'Home',
                        isSelected: widget.navigationShell.currentIndex == 0,
                        onTap: () => _goBranch(0),
                        isCollapsed: _isCollapsed,
                      ),
                      _SidebarItem(
                        icon: FontAwesomeIcons.folderOpen,
                        label: 'Library',
                        isSelected: widget.navigationShell.currentIndex == 1,
                        onTap: () => _goBranch(1),
                        isCollapsed: _isCollapsed,
                      ),
                      _SidebarItem(
                        icon: FontAwesomeIcons.brain,
                        label: 'AI Tutor',
                        isSelected: widget.navigationShell.currentIndex == 2,
                        onTap: () => _goBranch(2),
                        isProminent: true,
                        isCollapsed: _isCollapsed,
                      ),
                      _SidebarItem(
                        icon: FontAwesomeIcons.briefcase,
                        label: 'Tools',
                        isSelected: widget.navigationShell.currentIndex == 3,
                        onTap: () => _goBranch(3),
                        isCollapsed: _isCollapsed,
                      ),

                      const Spacer(),

                      // Profile Section (Bottom)
                      Padding(
                        padding: EdgeInsets.all(_isCollapsed ? 8 : 16),
                        child: InkWell(
                          onTap: () => _goBranch(4), // Profile Tab
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: widget.navigationShell.currentIndex == 4
                                  ? AppColors.accentTeal.withValues(alpha: 0.1)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: _isCollapsed
                                  ? MainAxisAlignment.center
                                  : MainAxisAlignment.start,
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                  child: ClipOval(
                                    child: NetworkAwareImage(
                                      imageUrl: user?.photoURL,
                                      isProfilePicture: true,
                                      errorWidget: Container(
                                        color: AppColors.primary,
                                        child: Center(
                                          child: Text(
                                            (user?.displayName != null &&
                                                    user!
                                                        .displayName
                                                        .isNotEmpty)
                                                ? user.displayName[0]
                                                      .toUpperCase()
                                                : 'S',
                                            style: GoogleFonts.outfit(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                if (!_isCollapsed) ...[
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'My Profile',
                                          style: GoogleFonts.inter(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black87,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          'Settings',
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Main Content
                Expanded(child: widget.navigationShell),
              ],
            ),
          );
        }
      },
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isProminent;
  final bool isCollapsed;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.isProminent = false,
    this.isCollapsed = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isCollapsed ? 8 : 16,
        vertical: 4,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Tooltip(
            message: isCollapsed ? label : "",
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.accentTeal.withValues(alpha: 0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: isSelected
                    ? Border.all(
                        color: AppColors.accentTeal.withValues(alpha: 0.3),
                      )
                    : null,
              ),
              child: Row(
                mainAxisAlignment: isCollapsed
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.start,
                children: [
                  FaIcon(
                    icon,
                    size: 18,
                    color: isSelected
                        ? AppColors.accentTeal
                        : (isDark ? Colors.grey[400] : Colors.grey[700]),
                  ),
                  if (!isCollapsed) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        label,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: isSelected
                              ? (isDark ? Colors.white : AppColors.accentTeal)
                              : (isDark ? Colors.grey[300] : Colors.grey[800]),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isProminent && !isSelected) ...[
                      const SizedBox(width: 8),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppColors.accentTeal,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ] else if (isProminent && !isSelected) ...[
                    // Show indicator even when collapsed if prominent
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        width: 4,
                        height: 4,
                        decoration: const BoxDecoration(
                          color: AppColors.accentTeal,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
