import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../providers/auth_provider.dart';
import '../../constants/colors.dart';
import '../../constants/strings.dart';

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
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Logo Section
                      _buildLogoSection(theme),
                      const SizedBox(height: 40),

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
                              "Welcome Back",
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

                            // Email Field
                            _buildTextField(
                              controller: _emailController,
                              label: "Email Address",
                              icon: FontAwesomeIcons.envelope,
                              keyboardType: TextInputType.emailAddress,
                              theme: theme,
                              textInputAction: TextInputAction.next,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter an email';
                                }
                                final emailRegex = RegExp(
                                  r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                                );
                                if (!emailRegex.hasMatch(value)) {
                                  return 'Enter a valid email address';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),

                            // Password Field
                            _buildTextField(
                              controller: _passwordController,
                              label: "Password",
                              icon: FontAwesomeIcons.lock,
                              obscureText: _obscurePassword,
                              theme: theme,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _submit(),
                              suffixIcon: IconButton(
                                icon: FaIcon(
                                  _obscurePassword
                                      ? FontAwesomeIcons.eyeSlash
                                      : FontAwesomeIcons.eye,
                                  size: 18,
                                  color: theme.iconTheme.color,
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
                              theme: theme,
                            ),

                            const SizedBox(height: 24),

                            // Divider
                            _buildDivider(theme),

                            const SizedBox(height: 24),

                            // Google Sign In Button
                            _buildGoogleButton(context, theme, isLoading),
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
                                color: theme.textTheme.bodyMedium?.color,
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required ThemeData theme,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
    TextInputAction? textInputAction,
    void Function(String)? onFieldSubmitted,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      textInputAction: textInputAction,
      onFieldSubmitted: onFieldSubmitted,
      style: theme.textTheme.bodyLarge,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: theme.textTheme.bodyMedium?.copyWith(
          color: theme.hintColor,
        ),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 16, right: 12),
          child: FaIcon(icon, size: 18, color: theme.primaryColor),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 50),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerHighest,
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
    required ThemeData theme,
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

  Widget _buildDivider(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: Divider(color: theme.dividerColor.withValues(alpha: 0.1)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            "OR",
            style: GoogleFonts.roboto(
              color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ),
        Expanded(
          child: Divider(color: theme.dividerColor.withValues(alpha: 0.1)),
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
}
