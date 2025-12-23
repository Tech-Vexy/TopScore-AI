import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../constants/colors.dart';
import '../providers/auth_provider.dart';
import '../tutor_client/chat_screen.dart';
import 'student/resources_screen.dart';
import 'tools/tools_screen.dart';
import 'support/support_screen.dart';
import 'subscription/subscription_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).userModel;
    final displayName = user?.displayName?.split(' ')[0] ?? 'Student';
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    // Adjusted breakpoints for 1200px max container
    final isWideScreen = screenWidth > 600;
    final isVeryWideScreen = screenWidth > 900;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          // Custom App Bar
          SliverAppBar(
            expandedHeight: 80,
            floating: true,
            pinned: true,
            elevation: 0,
            backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surface,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: EdgeInsets.only(
                left: isWideScreen ? 40 : 20,
                bottom: 16,
              ),
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const FaIcon(
                      FontAwesomeIcons.graduationCap,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'TopScore AI',
                    style: GoogleFonts.roboto(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: isDark ? AppColors.textDark : AppColors.text,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              Container(
                margin: EdgeInsets.only(right: isWideScreen ? 40 : 16),
                child: IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.surfaceVariantDark
                          : AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: FaIcon(
                      FontAwesomeIcons.rightFromBracket,
                      size: 16,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondary,
                    ),
                  ),
                  onPressed: () => Provider.of<AuthProvider>(
                    context,
                    listen: false,
                  ).signOut(),
                  tooltip: 'Sign Out',
                ),
              ),
            ],
          ),

          // Responsive Content
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isWideScreen ? 32 : 20,
                vertical: 20,
              ),
              child: isWideScreen
                  ? _buildWideLayout(
                      context,
                      displayName,
                      isDark,
                      isVeryWideScreen,
                    )
                  : _buildMobileLayout(context, displayName, isDark),
            ),
          ),
        ],
      ),
      // Floating Action Button for AI Chat
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ChatScreen()),
          );
        },
        backgroundColor: AppColors.accentTeal,
        icon: const FaIcon(FontAwesomeIcons.wandMagicSparkles, size: 18),
        label: Text(
          'Ask AI',
          style: GoogleFonts.roboto(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  // Wide screen layout (tablet/desktop)
  Widget _buildWideLayout(
    BuildContext context,
    String displayName,
    bool isDark,
    bool isVeryWide,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top row: Welcome card + Quick actions
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Card - takes 60% on wide, 50% on very wide
            Expanded(
              flex: isVeryWide ? 5 : 6,
              child: _buildWelcomeCard(context, displayName, isDark),
            ),
            const SizedBox(width: 24),
            // Quick Actions Grid
            Expanded(
              flex: isVeryWide ? 5 : 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader(context, 'Quick Actions', isDark),
                  const SizedBox(height: 16),
                  _buildQuickActionsGrid(context, isDark),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 40),

        // Premium Banner
        _buildPremiumBanner(context, isDark),

        const SizedBox(height: 100),
      ],
    );
  }

  // Mobile layout (original)
  Widget _buildMobileLayout(
    BuildContext context,
    String displayName,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildWelcomeCard(context, displayName, isDark),

        const SizedBox(height: 28),
        _buildSectionHeader(context, 'Quick Actions', isDark),
        const SizedBox(height: 16),
        _buildQuickActionsRow(context, isDark),

        const SizedBox(height: 24),
        _buildPremiumBanner(context, isDark),

        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, bool isDark) {
    return Text(
      title,
      style: GoogleFonts.roboto(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: isDark ? AppColors.textDark : AppColors.text,
      ),
    );
  }

  Widget _buildWelcomeCard(
    BuildContext context,
    String displayName,
    bool isDark,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryPurple.withValues(alpha: 0.4),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const FaIcon(
                  FontAwesomeIcons.handSparkles,
                  color: AppColors.accentTeal,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back,',
                      style: GoogleFonts.roboto(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                    Text(
                      '$displayName! 👋',
                      style: GoogleFonts.roboto(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                const FaIcon(
                  FontAwesomeIcons.lightbulb,
                  color: AppColors.accentTeal,
                  size: 18,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Ready to learn something new today?',
                    style: GoogleFonts.roboto(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ChatScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primaryPurple,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const FaIcon(FontAwesomeIcons.comments, size: 18),
                  const SizedBox(width: 10),
                  Text(
                    'Start Learning with AI',
                    style: GoogleFonts.roboto(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Quick actions for wide screens (grid layout)
  Widget _buildQuickActionsGrid(BuildContext context, bool isDark) {
    final quickActions = _getQuickActions();

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.3,
      children: quickActions
          .map(
            (action) => _buildQuickActionCard(
              context,
              icon: action['icon'] as IconData,
              label: action['label'] as String,
              color: action['color'] as Color,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => action['screen'] as Widget,
                ),
              ),
              isDark: isDark,
            ),
          )
          .toList(),
    );
  }

  // Quick actions for mobile (horizontal scroll)
  Widget _buildQuickActionsRow(BuildContext context, bool isDark) {
    final quickActions = _getQuickActions();

    return SizedBox(
      height: 110,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: quickActions.length,
        itemBuilder: (context, index) {
          final action = quickActions[index];
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: Duration(milliseconds: 400 + (index * 100)),
            curve: Curves.easeOutBack,
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: Opacity(opacity: value, child: child),
              );
            },
            child: Padding(
              padding: EdgeInsets.only(
                right: index < quickActions.length - 1 ? 12 : 0,
              ),
              child: _buildQuickActionCard(
                context,
                icon: action['icon'] as IconData,
                label: action['label'] as String,
                color: action['color'] as Color,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => action['screen'] as Widget,
                  ),
                ),
                isDark: isDark,
              ),
            ),
          );
        },
      ),
    );
  }

  List<Map<String, dynamic>> _getQuickActions() {
    return [
      {
        'icon': FontAwesomeIcons.brain,
        'label': 'AI Tutor',
        'color': AppColors.accentTeal,
        'screen': const ChatScreen(),
      },
      {
        'icon': FontAwesomeIcons.folderOpen,
        'label': 'Resources',
        'color': AppColors.cardGreen,
        'screen': const ResourcesScreen(),
      },
      {
        'icon': FontAwesomeIcons.toolbox,
        'label': 'Tools',
        'color': AppColors.cardPurple,
        'screen': const ToolsScreen(),
      },
      {
        'icon': FontAwesomeIcons.headset,
        'label': 'Support',
        'color': AppColors.cardPink,
        'screen': const SupportScreen(),
      },
    ];
  }

  Widget _buildQuickActionCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 90,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceElevatedDark : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.15),
              blurRadius: 15,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.03),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: FaIcon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: GoogleFonts.roboto(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.textDark : AppColors.text,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumBanner(BuildContext context, bool isDark) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const SubscriptionScreen()),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.accentTeal.withValues(alpha: 0.15),
              AppColors.accentGreen.withValues(alpha: 0.1),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.accentTeal.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: AppColors.accentGradient,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accentTeal.withValues(alpha: 0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const FaIcon(
                FontAwesomeIcons.crown,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Upgrade to Premium',
                    style: GoogleFonts.roboto(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isDark ? AppColors.textDark : AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Unlock unlimited access to all features',
                    style: GoogleFonts.roboto(
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.surfaceVariantDark
                    : AppColors.surfaceVariant,
                shape: BoxShape.circle,
              ),
              child: FaIcon(
                FontAwesomeIcons.chevronRight,
                size: 14,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
