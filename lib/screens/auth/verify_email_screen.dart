import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/auth_provider.dart';
import '../../constants/colors.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  bool isEmailVerified = false;
  bool canResendEmail = false;
  Timer? timer;

  @override
  void initState() {
    super.initState();

    // User should be logged in to be here
    isEmailVerified = Provider.of<AuthProvider>(
      context,
      listen: false,
    ).isEmailVerified;

    if (!isEmailVerified) {
      // Send verification email automatically on first visit
      Provider.of<AuthProvider>(
        context,
        listen: false,
      ).sendEmailVerification().catchError((e) {
        debugPrint("Initial verification email error: $e");
      });

      // Periodic check
      timer = Timer.periodic(
        const Duration(seconds: 3),
        (_) => checkEmailVerified(),
      );
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future checkEmailVerified() async {
    await Provider.of<AuthProvider>(context, listen: false).reloadUser();

    setState(() {
      isEmailVerified = Provider.of<AuthProvider>(
        context,
        listen: false,
      ).isEmailVerified;
    });

    if (isEmailVerified) timer?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return isEmailVerified
        ? const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ) // Will be redirected by AuthWrapper
        : Scaffold(
            appBar: AppBar(
              title: const Text('Verify Email'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.logout),
                  onPressed: () => Provider.of<AuthProvider>(
                    context,
                    listen: false,
                  ).signOut(),
                ),
              ],
            ),
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.mark_email_unread_outlined,
                    size: 80,
                    color: AppColors.primaryPurple,
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Check your Inbox!',
                    style: GoogleFonts.outfit(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'A verification email has been sent to your email address. Please click the link in the email to verify your account.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      backgroundColor: AppColors.primaryPurple,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.email),
                    label: const Text('Resend Email'),
                    onPressed: () async {
                      try {
                        await Provider.of<AuthProvider>(
                          context,
                          listen: false,
                        ).sendEmailVerification();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Verification email resent!'),
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to resend: $e')),
                          );
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    style: TextButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                    ),
                    child: const Text('Cancel', style: TextStyle(fontSize: 18)),
                    onPressed: () => Provider.of<AuthProvider>(
                      context,
                      listen: false,
                    ).signOut(),
                  ),
                ],
              ),
            ),
          );
  }
}
