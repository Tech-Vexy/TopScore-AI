import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/colors.dart';
import '../../services/subscription_service.dart';
import '../screens/subscription/subscription_screen.dart'; // Adjust path if needed

class PremiumFeatureGuard extends StatelessWidget {
  final Widget child;
  final Widget? customPaywall;

  const PremiumFeatureGuard({
    super.key,
    required this.child,
    this.customPaywall,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: SubscriptionService().isSessionPremium(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        bool isPremium = snapshot.data ?? false;

        if (isPremium) {
          return child; // Allow access
        } else {
          return customPaywall ??
              const PaywallView(); // Show "Upgrade to Premium"
        }
      },
    );
  }
}

class PaywallView extends StatelessWidget {
  const PaywallView({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.lock_outline,
              size: 64,
              color: AppColors.googleYellow,
            ),
            const SizedBox(height: 16),
            Text(
              "Premium Feature",
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Unlock this feature by upgrading your subscription.",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SubscriptionScreen(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.googleBlue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                "Upgrade Now",
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
