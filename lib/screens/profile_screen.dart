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
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: Text(
          "Profile",
          style: GoogleFonts.nunito(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        child: Column(
          children: [
            // --- 1. CLEAN HEADER ---
            _buildProfileHeader(context, user, isDark),

            const SizedBox(height: 32),

            // --- 2. ACCOUNT ---
            _buildSectionHeader(context, "Account"),
            _buildSettingsTile(
              context,
              icon: FontAwesomeIcons.crown,
              title: "Subscription",
              subtitle: (user?.isSubscribed ?? false) ? "Premium" : "Free Plan",
              iconColor: Colors.amber,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
              ),
              trailing: (user?.isSubscribed ?? false)
                  ? const Icon(Icons.check_circle,
                      color: Colors.green, size: 20)
                  : const Icon(Icons.arrow_forward_ios,
                      size: 14, color: Colors.grey),
            ),

            const SizedBox(height: 24),

            // --- 3. PREFERENCES ---
            _buildSectionHeader(context, "Preferences"),
            Consumer<SettingsProvider>(
              builder: (context, settings, _) {
                return _buildSettingsTile(
                  context,
                  icon: isDark ? FontAwesomeIcons.moon : FontAwesomeIcons.sun,
                  title: "Dark Mode",
                  iconColor: isDark ? Colors.deepPurple : Colors.orange,
                  trailing: Switch.adaptive(
                    value: isDark,
                    activeTrackColor: AppColors.accentTeal,
                    onChanged: (val) {
                      settings.setThemeMode(
                        val ? ThemeMode.dark : ThemeMode.light,
                      );
                    },
                  ),
                  onTap: () => settings.setThemeMode(
                    isDark ? ThemeMode.light : ThemeMode.dark,
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            _buildSettingsTile(
              context,
              icon: FontAwesomeIcons.language,
              title: "Language",
              subtitle:
                  user?.preferredLanguage == 'sw' ? 'Kiswahili' : 'English',
              iconColor: Colors.blueAccent,
              onTap: () =>
                  _showLanguageSelector(context, user?.preferredLanguage),
            ),

            const SizedBox(height: 24),

            // --- 4. LEGAL ---
            _buildSectionHeader(context, "About"),
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

            const SizedBox(height: 40),

            // --- 5. ACTIONS ---
            if (user != null) ...[
              _buildSettingsTile(
                context,
                icon: FontAwesomeIcons.rightFromBracket,
                title: "Log Out",
                iconColor: theme.colorScheme.error,
                textColor: theme.colorScheme.error,
                backgroundColor:
                    theme.colorScheme.error.withValues(alpha: 0.05),
                hasShadow: false,
                onTap: () async {
                  await authProvider.signOut();
                  if (context.mounted) {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  }
                },
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => _showDeleteConfirmation(context, authProvider),
                child: Text(
                  "Delete Account",
                  style: GoogleFonts.nunito(
                    color: Colors.grey,
                    fontSize: 13,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ] else ...[
              _buildSettingsTile(
                context,
                icon: FontAwesomeIcons.rightToBracket,
                title: "Sign In / Register",
                iconColor: AppColors.primaryPurple,
                textColor: AppColors.primaryPurple,
                hasShadow: false,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AuthScreen()),
                ),
              ),
              if (authProvider.isGuest) ...[
                const SizedBox(height: 12),
                _buildSettingsTile(
                  context,
                  icon: FontAwesomeIcons.eraser,
                  title: "Clear Guest Data",
                  iconColor: Colors.orange,
                  textColor: Colors.orange,
                  backgroundColor: Colors.orange.withValues(alpha: 0.05),
                  hasShadow: false,
                  onTap: () => _showClearGuestDialog(context, authProvider),
                ),
              ],
            ],

            const SizedBox(height: 30),
            Text(
              "v1.0.0",
              style: GoogleFonts.nunito(
                  color: Colors.grey.withValues(alpha: 0.5), fontSize: 11),
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
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.cardColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 15,
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
              ),
              child: (user?.photoURL == null || user!.photoURL!.isEmpty)
                  ? Center(
                      child: Text(
                        user?.displayName?.substring(0, 1).toUpperCase() ?? "G",
                        style: GoogleFonts.nunito(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: AppColors.accentTeal,
                        ),
                      ),
                    )
                  : null,
            ),
            if (user != null)
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.primaryPurple,
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: theme.scaffoldBackgroundColor, width: 2),
                  ),
                  child: const Icon(Icons.edit, color: Colors.white, size: 14),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          user?.displayName ?? "Guest Student",
          style: GoogleFonts.nunito(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        if (user?.email != null)
          Text(
            user!.email!,
            style: GoogleFonts.nunito(fontSize: 14, color: Colors.grey),
          ),
      ],
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title.toUpperCase(),
          style: GoogleFonts.nunito(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
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
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: FaIcon(icon, size: 16, color: iconColor),
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
                style: GoogleFonts.nunito(fontSize: 13, color: Colors.grey),
              )
            : null,
        trailing: trailing ??
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
      builder: (context) => SafeArea(
        child: Container(
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
            ],
          ),
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
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
              const Icon(Icons.check_circle,
                  color: AppColors.accentTeal, size: 20),
          ],
        ),
      ),
    );
  }

  void _showClearGuestDialog(BuildContext context, AuthProvider auth) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Clear Guest Data?"),
        content: const Text(
            "This will delete your anonymous chat history. This cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await auth.clearGuestSession();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Guest session cleared.")),
                );
              }
            },
            child: const Text("Clear"),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, AuthProvider auth) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Account?"),
        content: const Text(
          "This is permanent. Your data and subscription details will be wiped immediately.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
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
            child: const Text("Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
