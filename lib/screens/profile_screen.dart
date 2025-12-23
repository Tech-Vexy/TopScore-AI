import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../constants/colors.dart';
import '../providers/auth_provider.dart';
import 'subscription/subscription_screen.dart';
import 'legal/privacy_policy_screen.dart';
import 'legal/terms_of_use_screen.dart';

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
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios,
            color: isDark ? Colors.white : Colors.black,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Profile Settings",
          style: GoogleFonts.poppins(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // User Info
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.accentTeal.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        user?.displayName?.substring(0, 1).toUpperCase() ?? "U",
                        style: GoogleFonts.poppins(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: AppColors.accentTeal,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    user?.displayName ?? "User",
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.textDark : AppColors.text,
                    ),
                  ),
                  Text(
                    user?.email ?? "",
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: (user?.isSubscribed ?? false)
                          ? Colors.amber.withValues(alpha: 0.1)
                          : Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: (user?.isSubscribed ?? false)
                            ? Colors.amber
                            : Colors.grey,
                      ),
                    ),
                    child: Text(
                      (user?.isSubscribed ?? false) ? "Premium" : "Free Plan",
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: (user?.isSubscribed ?? false)
                            ? Colors.amber[700]
                            : Colors.grey,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Settings Sections
            _buildSectionHeader(context, "Subscription"),
            _buildTile(
              context,
              icon: FontAwesomeIcons.crown,
              title: "Manage Subscription",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SubscriptionScreen(),
                  ),
                );
              },
              iconColor: Colors.amber,
            ),

            const SizedBox(height: 24),
            _buildSectionHeader(context, "Preferences"),
            _buildTile(
              context,
              icon: FontAwesomeIcons.language,
              title: "Preferred Language",
              trailing: Text(
                user?.preferredLanguage == 'sw' ? 'Kiswahili' : 'English',
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black54,
                  fontSize: 14,
                ),
              ),
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  builder: (context) => Container(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "Select Language",
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ListTile(
                          title: const Text("English"),
                          trailing: user?.preferredLanguage != 'sw'
                              ? const Icon(
                                  Icons.check,
                                  color: AppColors.primary,
                                )
                              : null,
                          onTap: () {
                            context.read<AuthProvider>().updateLanguage('en');
                            Navigator.pop(context);
                          },
                        ),
                        ListTile(
                          title: const Text("Kiswahili"),
                          trailing: user?.preferredLanguage == 'sw'
                              ? const Icon(
                                  Icons.check,
                                  color: AppColors.primary,
                                )
                              : null,
                          onTap: () {
                            context.read<AuthProvider>().updateLanguage('sw');
                            Navigator.pop(context);
                          },
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 24),
            _buildSectionHeader(context, "Legal"),
            _buildTile(
              context,
              icon: FontAwesomeIcons.shieldHalved,
              title: "Privacy Policy",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PrivacyPolicyScreen(),
                  ),
                );
              },
            ),
            _buildTile(
              context,
              icon: FontAwesomeIcons.fileContract,
              title: "Terms of Use",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TermsOfUseScreen(),
                  ),
                );
              },
            ),

            const SizedBox(height: 24),
            _buildSectionHeader(context, "Account"),
            _buildTile(
              context,
              icon: FontAwesomeIcons.userPlus,
              title: "Invite a Friend",
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Invite feature coming soon!")),
                );
              },
              iconColor: AppColors.edupoaBlue,
            ),
            _buildTile(
              context,
              icon: FontAwesomeIcons.rightFromBracket,
              title: "Log Out",
              onTap: () async {
                await authProvider.signOut();
                if (context.mounted) {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                }
              },
              textColor: isDark ? AppColors.textDark : AppColors.text,
            ),
            _buildTile(
              context,
              icon: FontAwesomeIcons.trash,
              title: "Delete Account",
              onTap: () {
                _showDeleteConfirmation(context, authProvider);
              },
              textColor: Colors.red,
              iconColor: Colors.red,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? iconColor,
    Color? textColor,
    Widget? trailing,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultColor = isDark ? AppColors.textDark : AppColors.text;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: (iconColor ?? defaultColor).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: FaIcon(icon, size: 18, color: iconColor ?? defaultColor),
        ),
        title: Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: textColor ?? defaultColor,
          ),
        ),
        trailing:
            trailing ??
            const FaIcon(
              FontAwesomeIcons.chevronRight,
              size: 14,
              color: Colors.grey,
            ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, AuthProvider auth) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Account"),
        content: const Text(
          "Are you sure you want to delete your account? This action cannot be undone and all your data will be lost.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx); // Close dialog
              try {
                await auth.deleteAccount();
                if (context.mounted) {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text("Delete failed: $e")));
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }
}
