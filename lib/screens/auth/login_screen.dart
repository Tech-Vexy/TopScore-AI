import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../providers/auth_provider.dart';
import '../../constants/colors.dart';
import '../../constants/strings.dart';
import '../../services/recaptcha_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  @override
  void initState() {
    super.initState();
    // Load reCAPTCHA script only on auth pages
    RecaptchaService.loadRecaptchaScript();
  }
  
  @override
  Widget build(BuildContext context) {
    final isLoading = Provider.of<AuthProvider>(context).isLoading;
    final theme = Theme.of(context);

    return Scaffold(
      body: Container(
        color: theme.scaffoldBackgroundColor,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 32.0,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Logo Section
                    _buildLogoSection(theme),
                    const SizedBox(height: 60),

                    // Login Form Card
                    Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 30,
                            offset: const Offset(0, 10),
                          ),
                        ],
                        border: Border.all(
                          color: theme.dividerColor.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            "Welcome",
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Sign in to continue learning",
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.hintColor,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 32),

                          // Google Sign In Button
                          _buildGoogleButton(context, theme, isLoading),
                          
                          const SizedBox(height: 16),
                          
                          // Divider with "or"
                          Row(
                            children: [
                              Expanded(
                                child: Divider(
                                  color: theme.dividerColor.withValues(alpha: 0.3),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                  'or',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.hintColor,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Divider(
                                  color: theme.dividerColor.withValues(alpha: 0.3),
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Continue as Guest Button
                          _buildGuestButton(context, theme, isLoading),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoSection(ThemeData theme) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryPurple.withValues(alpha: 0.4),
                blurRadius: 25,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const FaIcon(
            FontAwesomeIcons.graduationCap,
            size: 40,
            color: AppColors.accentTeal,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          AppStrings.appName,
          style: GoogleFonts.roboto(
            fontSize: 30,
            fontWeight: FontWeight.bold,
            color: theme.textTheme.titleLarge?.color,
          ),
        ),
      ],
    );
  }

  Widget _buildGoogleButton(
    BuildContext context,
    ThemeData theme,
    bool isLoading,
  ) {
    return SizedBox(
      height: 56,
      child: OutlinedButton(
        onPressed: isLoading
            ? null
            : () async {
                try {
                  await Provider.of<AuthProvider>(
                    context,
                    listen: false,
                  ).signInWithGoogle();
                  if (mounted) {
                    Navigator.of(
                      this.context,
                    ).popUntil((route) => route.isFirst);
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(
                        content: Text("Google Sign In failed: ${e.toString()}"),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                }
              },
        style: OutlinedButton.styleFrom(
          backgroundColor: theme.cardColor,
          side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.3)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/images/google_logo.png',
              height: 24,
              width: 24,
              errorBuilder: (context, error, stackTrace) => const FaIcon(
                FontAwesomeIcons.google,
                size: 20,
                color: AppColors.error,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              "Continue with Google",
              style: GoogleFonts.roboto(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: theme.textTheme.bodyLarge?.color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuestButton(
    BuildContext context,
    ThemeData theme,
    bool isLoading,
  ) {
    return SizedBox(
      height: 56,
      child: TextButton(
        onPressed: isLoading
            ? null
            : () async {
                try {
                  await Provider.of<AuthProvider>(
                    context,
                    listen: false,
                  ).continueAsGuest();
                  if (mounted) {
                    Navigator.of(
                      this.context,
                    ).popUntil((route) => route.isFirst);
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(
                        content: Text("Guest sign in failed: ${e.toString()}"),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                }
              },
        style: TextButton.styleFrom(
          backgroundColor: theme.scaffoldBackgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: theme.dividerColor.withValues(alpha: 0.2),
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_outline_rounded,
              size: 24,
              color: theme.hintColor,
            ),
            const SizedBox(width: 12),
            Text(
              "Continue as Guest",
              style: GoogleFonts.roboto(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: theme.hintColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
