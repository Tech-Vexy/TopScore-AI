import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/ai_tutor_history_provider.dart';
import '../services/haptics_service.dart';
import '../constants/colors.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/image_cache_manager.dart';
import 'offline_banner.dart';

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
    HapticFeedback.lightImpact();
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
          return _buildMobileLayout(isDark);
        } else {
          return _buildDesktopLayout(isDark, user);
        }
      },
    );
  }

  Widget _buildMobileLayout(bool isDark) {
    return Scaffold(
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(child: widget.navigationShell),
        ],
      ),
      extendBody: true,
      bottomNavigationBar: _FloatingNavBar(
        currentIndex: widget.navigationShell.currentIndex,
        onTap: _goBranch,
        isDark: isDark,
      ),
    );
  }

  Widget _buildDesktopLayout(bool isDark, dynamic user) {
    return Scaffold(
      body: Row(
        children: [
          _DesktopSidebar(
            currentIndex: widget.navigationShell.currentIndex,
            onTap: _goBranch,
            isDark: isDark,
            isCollapsed: _isCollapsed,
            onToggle: _toggleSidebar,
            user: user,
          ),
          Expanded(child: widget.navigationShell),
        ],
      ),
    );
  }
}

// =============================================================================
// Mobile: Floating Bottom Navigation Bar
// =============================================================================

class _FloatingNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool isDark;

  const _FloatingNavBar({
    required this.currentIndex,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        bottom: bottomPadding > 0 ? bottomPadding : 10,
        top: 6,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF16161E).withValues(alpha: 0.95)
            : Colors.white.withValues(alpha: 0.95),
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.06),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        bottom: false,
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1F28) : const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Row(
            children: List.generate(5, (index) {
              final item = _navItems[index];

              return Expanded(
                child: Consumer2<NotificationProvider, AiTutorHistoryProvider>(
                  builder: (context, notifProvider, historyProvider, child) {
                    int badgeCount = 0;
                    if (index == 0) badgeCount = notifProvider.unreadCount;
                    if (index == 2) badgeCount = historyProvider.unreadCount;

                    return _NavBarButton(
                      icon: item.icon,
                      label: item.label,
                      isSelected: currentIndex == index,
                      isProminent: item.isProminent,
                      onTap: () {
                        HapticsService.instance.lightImpact();
                        onTap(index);
                      },
                      isDark: isDark,
                      badgeCount: badgeCount,
                    );
                  },
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItemData {
  final IconData icon;
  final String label;
  final bool isProminent;

  const _NavItemData({
    required this.icon,
    required this.label,
    this.isProminent = false,
  });
}

const _navItems = [
  _NavItemData(icon: FontAwesomeIcons.house, label: 'Home'),
  _NavItemData(icon: FontAwesomeIcons.folderOpen, label: 'Library'),
  _NavItemData(
      icon: FontAwesomeIcons.brain, label: 'AI Tutor', isProminent: true),
  _NavItemData(icon: FontAwesomeIcons.briefcase, label: 'Tools'),
  _NavItemData(icon: FontAwesomeIcons.user, label: 'Profile'),
];

class _NavBarButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final bool isProminent;
  final VoidCallback onTap;
  final bool isDark;
  final int badgeCount;

  const _NavBarButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.isProminent,
    required this.onTap,
    required this.isDark,
    this.badgeCount = 0,
  });

  @override
  State<_NavBarButton> createState() => _NavBarButtonState();
}

class _NavBarButtonState extends State<_NavBarButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 120),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.88).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  Color get _activeColor {
    if (widget.isProminent && widget.isSelected) return AppColors.accentTeal;
    if (widget.isSelected) {
      return widget.isDark ? Colors.white : AppColors.primary;
    }
    return widget.isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;
  }

  Color get _bgColor {
    if (!widget.isSelected) return Colors.transparent;
    if (widget.isProminent) {
      return AppColors.accentTeal.withValues(alpha: 0.15);
    }
    return widget.isDark
        ? Colors.white.withValues(alpha: 0.1)
        : AppColors.primary.withValues(alpha: 0.1);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _scaleController.forward(),
      onTapUp: (_) {
        _scaleController.reverse();
        widget.onTap();
      },
      onTapCancel: () => _scaleController.reverse(),
      behavior: HitTestBehavior.opaque,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _bgColor,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Stack(
                  key: ValueKey(widget.isSelected),
                  alignment: Alignment.center,
                  children: [
                    FaIcon(
                      widget.icon,
                      size: widget.isSelected ? 19 : 18,
                      color: _activeColor,
                    ),
                    if (widget.badgeCount > 0)
                      Positioned(
                        right: -4,
                        top: -4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: AppColors.error,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 14,
                            minHeight: 14,
                          ),
                          child: Text(
                            '${widget.badgeCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: GoogleFonts.inter(
                  fontSize: widget.isSelected ? 11 : 10,
                  fontWeight:
                      widget.isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: _activeColor,
                ),
                child: Text(widget.label),
              ),
              // Active dot indicator
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                margin: const EdgeInsets.only(top: 3),
                width: widget.isSelected ? 5 : 0,
                height: widget.isSelected ? 5 : 0,
                decoration: BoxDecoration(
                  color:
                      widget.isProminent ? AppColors.accentTeal : _activeColor,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Desktop: Enhanced Sidebar
// =============================================================================

class _DesktopSidebar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool isDark;
  final bool isCollapsed;
  final VoidCallback onToggle;
  final dynamic user;

  const _DesktopSidebar({
    required this.currentIndex,
    required this.onTap,
    required this.isDark,
    required this.isCollapsed,
    required this.onToggle,
    required this.user,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      width: isCollapsed ? 80 : 260,
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        border: Border(
          right: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.05),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
            blurRadius: 12,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          // Logo Header
          _buildLogoHeader(),
          const SizedBox(height: 12),
          // Navigation Items
          ...List.generate(4, (i) {
            final item = _navItems[i];
            return _SidebarItem(
              icon: item.icon,
              label: item.label,
              isSelected: currentIndex == i,
              onTap: () => onTap(i),
              isProminent: item.isProminent,
              isCollapsed: isCollapsed,
              isDark: isDark,
            );
          }),
          const Spacer(),
          _buildSyncInfo(context),
          // Profile Section
          _buildProfileSection(context),
        ],
      ),
    );
  }

  Widget _buildLogoHeader() {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isCollapsed ? 12 : 24,
        vertical: 24,
      ),
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisAlignment:
            isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
        children: [
          if (!isCollapsed) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.accentTeal.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Image.asset(
                'assets/images/launcher_icon.png',
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
                  color: isDark ? Colors.white : Colors.black87,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          IconButton(
            icon: Icon(
              isCollapsed ? Icons.chevron_right : Icons.chevron_left,
              size: 20,
              color: Colors.grey,
            ),
            onPressed: onToggle,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncInfo(BuildContext context) {
    if (isCollapsed) return const SizedBox.shrink();

    return Consumer<AiTutorHistoryProvider>(
      builder: (context, provider, child) {
        final lastFetch = provider.lastFetchTime;
        if (lastFetch == null) return const SizedBox.shrink();

        final timeStr = DateFormat('h:mm a').format(lastFetch);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Row(
            children: [
              Icon(
                Icons.sync_rounded,
                size: 12,
                color: Colors.grey.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 8),
              Text(
                'Last updated at $timeStr',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: Colors.grey.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProfileSection(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(isCollapsed ? 8 : 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onTap(4),
          borderRadius: BorderRadius.circular(12),
          hoverColor: AppColors.accentTeal.withValues(alpha: 0.06),
          splashColor: AppColors.accentTeal.withValues(alpha: 0.12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: currentIndex == 4
                  ? AppColors.accentTeal.withValues(alpha: 0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: currentIndex == 4
                  ? Border.all(
                      color: AppColors.accentTeal.withValues(alpha: 0.25))
                  : null,
            ),
            child: Row(
              mainAxisAlignment: isCollapsed
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 17,
                  backgroundColor: AppColors.primary,
                  backgroundImage:
                      (user?.photoURL != null && user!.photoURL!.isNotEmpty)
                          ? CachedNetworkImageProvider(
                              user.photoURL!,
                              cacheManager: ProfileImageCacheManager(),
                            )
                          : null,
                  child: (user?.photoURL == null || user!.photoURL!.isEmpty)
                      ? Text(
                          (user?.displayName != null &&
                                  user!.displayName.isNotEmpty)
                              ? user.displayName[0].toUpperCase()
                              : 'S',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        )
                      : null,
                ),
                if (!isCollapsed) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'My Profile',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
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
    );
  }
}

// =============================================================================
// Desktop: Sidebar Item with Hover Effect
// =============================================================================

class _SidebarItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isProminent;
  final bool isCollapsed;
  final bool isDark;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.isProminent = false,
    this.isCollapsed = false,
    required this.isDark,
  });

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final activeColor = widget.isSelected
        ? AppColors.accentTeal
        : (widget.isDark ? Colors.grey[400]! : Colors.grey[700]!);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: widget.isCollapsed ? 8 : 16,
        vertical: 3,
      ),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              HapticsService.instance.lightImpact();
              widget.onTap();
            },
            borderRadius: BorderRadius.circular(12),
            hoverColor: Colors.transparent,
            splashColor: AppColors.accentTeal.withValues(alpha: 0.12),
            child: Tooltip(
              message: widget.isCollapsed ? widget.label : "",
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: widget.isSelected
                      ? AppColors.accentTeal.withValues(alpha: 0.15)
                      : _isHovered
                          ? (widget.isDark
                              ? Colors.white.withValues(alpha: 0.04)
                              : Colors.black.withValues(alpha: 0.03))
                          : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: widget.isSelected
                      ? Border.all(
                          color: AppColors.accentTeal.withValues(alpha: 0.3),
                        )
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: widget.isCollapsed
                      ? MainAxisAlignment.center
                      : MainAxisAlignment.start,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        FaIcon(
                          widget.icon,
                          size: 18,
                          color: _isHovered && !widget.isSelected
                              ? (widget.isDark
                                  ? Colors.grey[300]
                                  : Colors.grey[600])
                              : activeColor,
                        ),
                        if (widget.isCollapsed &&
                            widget.isProminent &&
                            !widget.isSelected)
                          Positioned(
                            right: -4,
                            top: -4,
                            child: Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: AppColors.accentTeal,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (!widget.isCollapsed) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.label,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: widget.isSelected
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: widget.isSelected
                                ? (widget.isDark
                                    ? Colors.white
                                    : AppColors.accentTeal)
                                : _isHovered
                                    ? (widget.isDark
                                        ? Colors.grey[200]
                                        : Colors.grey[700])
                                    : (widget.isDark
                                        ? Colors.grey[300]
                                        : Colors.grey[800]),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (widget.isProminent && !widget.isSelected) ...[
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
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
