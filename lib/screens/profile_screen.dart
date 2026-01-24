import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../constants/colors.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/image_cache_manager.dart';
import 'subscription/subscription_screen.dart';
import 'legal/privacy_policy_screen.dart';
import 'legal/terms_of_use_screen.dart';
import 'auth/auth_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.userModel;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false, // Remove back button
        title: Text(
          "My Profile",
          style: GoogleFonts.nunito(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_note, color: AppColors.primaryPurple),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Edit Profile coming soon!")),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        child: Column(
          children: [
            // --- 1. PROFILE HEADER ---
            _buildProfileHeader(context, user, isDark),

            const SizedBox(height: 24),

            // --- 2. STATS ROW (Gamification) ---
            _buildStatsRow(context, isDark),

            const SizedBox(height: 32),

            // --- 3. SETTINGS SECTIONS ---
            _buildSectionHeader(context, "Account Settings"),
            _buildSettingsTile(
              context,
              icon: FontAwesomeIcons.crown,
              title: "Manage Subscription",
              subtitle: (user?.isSubscribed ?? false)
                  ? "Active Premium"
                  : "Free Plan",
              iconColor: Colors.amber,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
              ),
              trailing: (user?.isSubscribed ?? false)
                  ? const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 20,
                    )
                  : const Icon(
                      Icons.arrow_forward_ios,
                      size: 14,
                      color: Colors.grey,
                    ),
            ),

            const SizedBox(height: 20),
            _buildSectionHeader(context, "App Preferences"),

            Consumer<SettingsProvider>(
              builder: (context, settings, _) {
                return _buildSettingsTile(
                  context,
                  icon: isDark ? FontAwesomeIcons.moon : FontAwesomeIcons.sun,
                  title: "Dark Mode",
                  subtitle: isDark ? "Enabled" : "Disabled",
                  iconColor: isDark ? Colors.deepPurple : Colors.amber,
                  trailing: Switch.adaptive(
                    value: isDark,
                    activeTrackColor: AppColors.accentTeal,
                    onChanged: (val) {
                      settings.setThemeMode(
                        val ? ThemeMode.dark : ThemeMode.light,
                      );
                    },
                  ),
                  onTap: () {
                    settings.setThemeMode(
                      isDark ? ThemeMode.light : ThemeMode.dark,
                    );
                  },
                );
              },
            ),

            const SizedBox(height: 12),

            Consumer<SettingsProvider>(
              builder: (context, settings, _) {
                return _buildSettingsTile(
                  context,
                  icon: FontAwesomeIcons.bolt,
                  title: "Lite Mode",
                  subtitle: "Save data by reducing animations",
                  iconColor: Colors.blueAccent,
                  trailing: Switch.adaptive(
                    value: settings.isLiteMode,
                    activeTrackColor: AppColors.accentTeal,
                    onChanged: (val) => settings.toggleLiteMode(val),
                  ),
                  onTap: () => settings.toggleLiteMode(!settings.isLiteMode),
                );
              },
            ),

            const SizedBox(height: 12),

            _buildSettingsTile(
              context,
              icon: FontAwesomeIcons.language,
              title: "Language",
              subtitle: user?.preferredLanguage == 'sw'
                  ? 'Kiswahili'
                  : 'English',
              iconColor: Colors.purpleAccent,
              onTap: () =>
                  _showLanguageSelector(context, user?.preferredLanguage),
            ),

            const SizedBox(height: 20),
            _buildSectionHeader(context, "Legal & Support"),
            _buildSettingsTile(
              context,
              icon: FontAwesomeIcons.shieldHalved,
              title: "Privacy Policy",
              iconColor: Colors.teal,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
              ),
            ),
            const SizedBox(height: 12),
            _buildSettingsTile(
              context,
              icon: FontAwesomeIcons.fileContract,
              title: "Terms of Use",
              iconColor: Colors.teal,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TermsOfUseScreen()),
              ),
            ),

            const SizedBox(height: 32),

            // --- 4. DANGER ZONE ---
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: theme.colorScheme.error.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: theme.colorScheme.error.withValues(alpha: 0.1),
                ),
              ),
              child: Column(
                children: [
                  // Auth Actions
                  ...(user != null
                      ? [
                          _buildSettingsTile(
                            context,
                            icon: FontAwesomeIcons.rightFromBracket,
                            title: "Log Out",
                            iconColor: theme.colorScheme.error,
                            textColor: theme.colorScheme.error,
                            hasShadow: false,
                            onTap: () async {
                              await authProvider.signOut();
                              if (context.mounted) {
                                Navigator.of(context).pop();
                              }
                            },
                          )
                        ]
                      : [
                          _buildSettingsTile(
                            context,
                            icon: FontAwesomeIcons.rightToBracket,
                            title: "Sign In / Register",
                            iconColor: AppColors.primaryPurple,
                            textColor: AppColors.primaryPurple,
                            hasShadow: false,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const AuthScreen(),
                                ),
                              );
                            },
                          ),
                          if (authProvider.isGuest)
                            _buildSettingsTile(
                              context,
                              icon: FontAwesomeIcons.eraser,
                              title: "Clear Guest Session",
                              subtitle: "Start fresh on this device",
                              iconColor: Colors.orange,
                              textColor: Colors.orange,
                              hasShadow: false,
                              onTap: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text("Clear Guest Session?"),
                                    content: const Text(
                                        "This will delete your current anonymous history. Ensure you don't need it or sign in to save it."),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx, false),
                                        child: const Text("Cancel"),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx, true),
                                        child: const Text("Clear"),
                                      ),
                                    ],
                                  ),
                                );

                                if (confirm == true) {
                                  await authProvider.clearGuestSession();
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text("Guest session cleared.")),
                                    );
                                  }
                                }
                              },
                            ),
                        ]),

                  Divider(
                    height: 1,
                    color: theme.colorScheme.error.withValues(alpha: 0.1),
                  ),
                  _buildSettingsTile(
                    context,
                    icon: FontAwesomeIcons.trashCan,
                    title: "Delete Account",
                    iconColor: theme.colorScheme.error,
                    textColor: theme.colorScheme.error,
                    hasShadow: false,
                    backgroundColor: Colors.transparent,
                    onTap: () => _showDeleteConfirmation(context, authProvider),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),

            // Version Info
            Text(
              "TopScore AI v1.0.0",
              style: GoogleFonts.nunito(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // --- WIDGET BUILDERS ---

  Widget _buildProfileHeader(BuildContext context, dynamic user, bool isDark) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Stack(
          children: [
            // Avatar
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.accentTeal.withValues(alpha: 0.5),
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accentTeal.withValues(alpha: 0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 5),
                  ),
                ],
                image: (user?.photoURL != null && user!.photoURL!.isNotEmpty)
                    ? DecorationImage(
                        image: CachedNetworkImageProvider(
                          user.photoURL!,
                          cacheManager: ProfileImageCacheManager(),
                        ),
                        fit: BoxFit.cover,
                      )
                    : null,
                color: theme.cardColor,
              ),
              child: (user?.photoURL == null || user!.photoURL!.isEmpty)
                  ? Center(
                      child: Text(
                        user?.displayName?.substring(0, 1).toUpperCase() ?? "U",
                        style: GoogleFonts.nunito(
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                          color: AppColors.accentTeal,
                        ),
                      ),
                    )
                  : null,
            ),
            // Edit Badge
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryPurple,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(
                  Icons.camera_alt,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          user?.displayName ?? "Student",
          style: GoogleFonts.nunito(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        Text(
          user?.email ?? "",
          style: GoogleFonts.nunito(fontSize: 14, color: Colors.grey),
        ),
        const SizedBox(height: 12),
        // Badges Row
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildBadge(
              text: (user?.role ?? "Student").toString().toUpperCase(),
              color: AppColors.primaryPurple,
            ),
            const SizedBox(width: 8),
            if (user?.isSubscribed ?? false)
              _buildBadge(text: "PRO", color: Colors.amber, icon: Icons.star),
          ],
        ),
      ],
    );
  }

  Widget _buildBadge({
    required String text,
    required Color color,
    IconData? icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: GoogleFonts.nunito(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(BuildContext context, bool isDark) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatItem(context, "LEVEL", "5", Colors.blue),
          _buildVerticalDivider(),
          _buildStatItem(context, "STREAK", "12", Colors.orange),
          _buildVerticalDivider(),
          _buildStatItem(context, "POINTS", "840", Colors.green),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    String label,
    String value,
    Color color,
  ) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.nunito(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.nunito(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: color,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      height: 30,
      width: 1,
      color: Colors.grey.withValues(alpha: 0.2),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: GoogleFonts.nunito(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    required Color iconColor,
    Color? textColor,
    Widget? trailing,
    bool hasShadow = true,
    Color? backgroundColor,
  }) {
    final theme = Theme.of(context);
    final bgColor = backgroundColor ?? theme.cardColor;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: hasShadow
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: FaIcon(icon, size: 18, color: iconColor),
        ),
        title: Text(
          title,
          style: GoogleFonts.nunito(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: textColor ?? theme.colorScheme.onSurface,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: GoogleFonts.nunito(fontSize: 12, color: Colors.grey),
              )
            : null,
        trailing:
            trailing ??
            const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
      ),
    );
  }

  void _showLanguageSelector(BuildContext context, String? currentLang) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Select Language",
              style: GoogleFonts.nunito(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildLanguageOption(context, "English", "en", currentLang),
            const SizedBox(height: 12),
            _buildLanguageOption(context, "Kiswahili", "sw", currentLang),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageOption(
    BuildContext context,
    String name,
    String code,
    String? current,
  ) {
    final isSelected = current == code;
    return InkWell(
      onTap: () {
        context.read<AuthProvider>().updateLanguage(code);
        Navigator.pop(context);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.accentTeal.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppColors.accentTeal
                : Colors.grey.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(name, style: GoogleFonts.nunito(fontWeight: FontWeight.w600)),
            if (isSelected)
              const Icon(Icons.check_circle, color: AppColors.accentTeal),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, AuthProvider auth) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          "Delete Account",
          style: GoogleFonts.nunito(fontWeight: FontWeight.bold),
        ),
        content: Text(
          "This is permanent. Your data, progress, and subscription details will be wiped.",
          style: GoogleFonts.nunito(),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              "Cancel",
              style: GoogleFonts.nunito(fontWeight: FontWeight.bold),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await auth.deleteAccount();
              if (context.mounted) {
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(
              "Delete",
              style: GoogleFonts.nunito(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
