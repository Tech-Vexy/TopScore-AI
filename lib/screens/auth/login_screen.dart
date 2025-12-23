import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../providers/auth_provider.dart';
import '../../constants/colors.dart';
import '../../constants/strings.dart';

import 'package:flutter/foundation.dart' show kIsWeb;
import '../../utils/recaptcha/recaptcha_util.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onToggle;
  const LoginScreen({super.key, required this.onToggle});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      try {
        if (kIsWeb) {
          debugPrint("Generating reCAPTCHA token...");
          final token = await getRecaptchaToken();
          debugPrint("reCAPTCHA Token: $token");
          // TODO: Send this token to backend for verification
          if (token == null) {
            // Decide if we want to block login or allow it.
            // For now, logging error but generally we might want to allow
            // generic error if it's just a network glitch vs bot detetion.
            debugPrint("Warning: reCAPTCHA token was null");
          }
        }

        if (!mounted) return;

        await Provider.of<AuthProvider>(
          context,
          listen: false,
        ).signIn(_emailController.text.trim(), _passwordController.text.trim());
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Login failed: ${e.toString()}"),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = Provider.of<AuthProvider>(context).isLoading;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? AppColors.darkGradient : null,
          color: isDark ? null : AppColors.background,
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 32.0,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Logo Section
                      _buildLogoSection(isDark),
                      const SizedBox(height: 40),

                      // Login Form Card
                      Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.surfaceElevatedDark
                              : AppColors.surface,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(
                                alpha: isDark ? 0.3 : 0.08,
                              ),
                              blurRadius: 30,
                              offset: const Offset(0, 10),
                            ),
                          ],
                          border: Border.all(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.05)
                                : Colors.black.withValues(alpha: 0.03),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              "Welcome Back",
                              style: GoogleFonts.roboto(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? AppColors.textDark
                                    : AppColors.text,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Sign in to continue learning",
                              style: GoogleFonts.roboto(
                                fontSize: 14,
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 32),

                            // Email Field
                            _buildTextField(
                              controller: _emailController,
                              label: "Email Address",
                              icon: FontAwesomeIcons.envelope,
                              keyboardType: TextInputType.emailAddress,
                              isDark: isDark,
                              validator: (value) =>
                                  value != null && value.contains('@')
                                  ? null
                                  : "Enter a valid email",
                            ),
                            const SizedBox(height: 20),

                            // Password Field
                            _buildTextField(
                              controller: _passwordController,
                              label: "Password",
                              icon: FontAwesomeIcons.lock,
                              obscureText: _obscurePassword,
                              isDark: isDark,
                              suffixIcon: IconButton(
                                icon: FaIcon(
                                  _obscurePassword
                                      ? FontAwesomeIcons.eyeSlash
                                      : FontAwesomeIcons.eye,
                                  size: 18,
                                  color: isDark
                                      ? AppColors.textSecondaryDark
                                      : AppColors.textSecondary,
                                ),
                                onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                              ),
                              validator: (value) =>
                                  value != null && value.length >= 6
                                  ? null
                                  : "Password must be at least 6 characters",
                            ),

                            const SizedBox(height: 12),

                            // Forgot Password
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () {},
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  "Forgot Password?",
                                  style: GoogleFonts.roboto(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.accentTeal,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 28),

                            // Login Button
                            _buildPrimaryButton(
                              onPressed: isLoading ? null : _submit,
                              isLoading: isLoading,
                              label: "Sign In",
                              icon: FontAwesomeIcons.rightToBracket,
                            ),

                            const SizedBox(height: 24),

                            // Divider
                            _buildDivider(isDark),

                            const SizedBox(height: 24),

                            // Google Sign In Button
                            _buildGoogleButton(context, isDark, isLoading),
                          ],
                        ),
                      ),

                      const SizedBox(height: 28),

                      // Sign Up Link
                      Center(
                        child: TextButton(
                          onPressed: widget.onToggle,
                          child: RichText(
                            text: TextSpan(
                              text: "Don't have an account? ",
                              style: GoogleFonts.roboto(
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondary,
                              ),
                              children: [
                                TextSpan(
                                  text: "Sign Up",
                                  style: GoogleFonts.roboto(
                                    color: AppColors.accentTeal,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoSection(bool isDark) {
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
            color: isDark ? AppColors.textDark : AppColors.text,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isDark,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      style: GoogleFonts.roboto(
        color: isDark ? AppColors.textDark : AppColors.text,
        fontSize: 15,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.roboto(
          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
          fontSize: 14,
        ),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 16, right: 12),
          child: FaIcon(icon, size: 18, color: AppColors.accentTeal),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 50),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: isDark
            ? AppColors.surfaceVariantDark
            : AppColors.surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.accentTeal, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.error, width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
      ),
      validator: validator,
    );
  }

  Widget _buildPrimaryButton({
    required VoidCallback? onPressed,
    required bool isLoading,
    required String label,
    required IconData icon,
  }) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        gradient: AppColors.accentGradient,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentTeal.withValues(alpha: 0.4),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FaIcon(icon, size: 18, color: Colors.white),
                  const SizedBox(width: 10),
                  Text(
                    label,
                    style: GoogleFonts.roboto(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: Divider(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.1),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            "OR",
            style: GoogleFonts.roboto(
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondary,
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ),
        Expanded(
          child: Divider(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.1),
          ),
        ),
      ],
    );
  }

  Widget _buildGoogleButton(BuildContext context, bool isDark, bool isLoading) {
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
          backgroundColor: isDark
              ? AppColors.surfaceVariantDark
              : AppColors.surface,
          side: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.1),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Image.asset(
                'assets/images/google_logo.png',
                height: 20,
                width: 20,
                errorBuilder: (context, error, stackTrace) => const FaIcon(
                  FontAwesomeIcons.google,
                  size: 18,
                  color: AppColors.error,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              "Continue with Google",
              style: GoogleFonts.roboto(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: isDark ? AppColors.textDark : AppColors.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
