import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class SubscriptionService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Checks if the current session has premium access
  Future<bool> isSessionPremium() async {
    User? user = _auth.currentUser;
    if (user == null) return false;

    try {
      // 1. Force Refresh the Token
      // This fetches the new 'claims' from the server (critical after payment)
      IdTokenResult tokenResult = await user.getIdTokenResult(true);

      // 2. Check the claims
      Map<String, dynamic>? claims = tokenResult.claims;

      debugPrint("Token Claims: $claims");

      if (claims?['plan'] == 'premium') {
        // Check expiry client-side too
        int expiry = claims?['expiry'] ?? 0;
        bool isActive = DateTime.now().millisecondsSinceEpoch / 1000 < expiry;
        return isActive;
      }

      return false;
    } catch (e) {
      debugPrint("Error checking premium status: $e");
      return false;
    }
  }

  /// Checks if the current session has premium access OR is within the 7-day trial
  Future<bool> isSessionPremiumOrTrial() async {
    User? user = _auth.currentUser;
    if (user == null) return false;

    // 1. Check strict premium status
    if (await isSessionPremium()) return true;

    // 2. Check 7-day trial status
    if (user.metadata.creationTime != null) {
      final now = DateTime.now();
      final difference = now.difference(user.metadata.creationTime!);
      if (difference.inDays < 7) {
        return true;
      }
    }

    return false;
  }

  /// Call this immediately after M-Pesa payment success
  Future<void> refreshSubscriptionStatus() async {
    await isSessionPremium();
    // This forces the SDK to download the new token with the 'premium' badge
  }
}
