import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();

  bool _requiresEmailVerification = false;

  UserModel? _userModel;
  UserModel? get userModel => _userModel;

  bool get requiresEmailVerification => _requiresEmailVerification;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  // Guest mode (disabled)
  bool _isGuest = false;
  bool get isGuest => _isGuest;

  int _guestMessageCount = 0;
  int _guestDocumentCount = 0;

  static const int kGuestMessageLimit = 5;
  static const int kGuestDocumentLimit = 3;

  bool get isAuthOrGuest => _userModel != null || _isGuest;

  Future<void> continueAsGuest() async {
    throw Exception('Guest access is disabled. Please sign in.');
  }

  bool get canSendMessage {
    if (_userModel != null) return true;
    return _guestMessageCount < kGuestMessageLimit;
  }

  void incrementGuestMessage() {
    if (_isGuest) {
      _guestMessageCount++;
    }
  }

  bool get canOpenDocument {
    if (_userModel != null) return true;
    return _guestDocumentCount < kGuestDocumentLimit;
  }

  void incrementGuestDocument() {
    if (_isGuest) {
      _guestDocumentCount++;
    }
  }

  bool get needsRoleSelection => false;

  Future<void> init() async {
    _setLoading(true);
    try {
      await _authService.ensureBlockedEmailDomainsLoaded();
      User? user = _authService.currentUser;
      if (user != null) {
        if (user.isAnonymous) {
          debugPrint(
              "Anonymous user detected but guest mode is disabled. Signing out...");
          await _authService.signOut();
          _userModel = null;
          return;
        }

        await user.reload();
        user = _authService.currentUser;
        if (user == null || !user.emailVerified) {
          _requiresEmailVerification = user != null;
          _userModel = null;
          return;
        }

        _userModel = await _authService.getUserProfile(user.uid);
      }
    } catch (e) {
      debugPrint("AuthProvider init error: $e");
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _ensureUserProfile(User user) async {
    final existing = await _authService.getUserProfile(user.uid);
    if (existing != null) {
      _userModel = existing;
    } else {
      final newUser = UserModel(
        uid: user.uid,
        email: user.email ?? '',
        displayName: user.displayName ?? 'New User',
        photoURL: user.photoURL,
        role: '',
        grade: null,
        schoolName: '',
        linkCode: _generateLinkCode(),
      );
      await _authService.updateUserProfile(user.uid, newUser.toMap());
      _userModel = newUser;
    }
  }

  // --- GOOGLE SIGN IN ---
  Future<bool> signInWithGoogle() async {
    try {
      _setLoading(true);
      final user = await _authService.signInWithGoogle();

      if (user != null) {
        _requiresEmailVerification = false;
        await _ensureUserProfile(user);
        notifyListeners();
        return true;
      }
    } catch (e) {
      debugPrint("Google Sign In Error: $e");
      rethrow;
    } finally {
      _setLoading(false);
    }
    return false;
  }

  // --- EMAIL SIGN IN ---
  Future<bool> signInWithEmail(String email, String password) async {
    try {
      _setLoading(true);
      final credential = await _authService.signInWithEmail(email, password);
      final user = credential?.user;
      if (user == null) return false;

      await user.reload();
      final refreshedUser = _authService.currentUser;
      if (refreshedUser == null || !refreshedUser.emailVerified) {
        _requiresEmailVerification = true;
        await _authService.sendEmailVerification();
        _userModel = null;
        notifyListeners();
        return false;
      }

      _requiresEmailVerification = false;
      await _ensureUserProfile(refreshedUser);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint("Email Sign In Error: $e");
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // --- EMAIL SIGN UP ---
  Future<bool> signUpWithEmail(String email, String password) async {
    try {
      _setLoading(true);
      final credential = await _authService.signUpWithEmail(email, password);
      final user = credential?.user;
      if (user != null) {
        // Send verification email in the background, but don't block login
        await user.sendEmailVerification().catchError((e) {
          debugPrint("Failed to send verification email: $e");
        });

        _requiresEmailVerification = false;
        await _ensureUserProfile(user);
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("Email Sign Up Error: $e");
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> sendPasswordReset(String email) async {
    await _authService.sendPasswordReset(email);
  }

  Future<void> resendEmailVerification() async {
    await _authService.sendEmailVerification();
  }

  Future<bool> reloadAndCheckEmailVerified() async {
    final user = _authService.currentUser;
    if (user == null) return false;
    await user.reload();
    final refreshedUser = _authService.currentUser;
    if (refreshedUser == null || !refreshedUser.emailVerified) {
      _requiresEmailVerification = true;
      notifyListeners();
      return false;
    }
    _requiresEmailVerification = false;
    await _ensureUserProfile(refreshedUser);
    notifyListeners();
    return true;
  }

  Future<void> clearGuestSession() async {
    try {
      final user = _authService.currentUser;
      if (user != null && user.isAnonymous) {
        await user.delete();
      }
      await signOut();
    } catch (e) {
      debugPrint("Error clearing guest session: $e");
      await signOut();
    }
  }

  Future<void> updateUserRole({
    required String role,
    required String grade,
    required String schoolName,
    String? displayName,
    String? phoneNumber,
    String? curriculum,
    String? educationLevel,
    List<String>? interests,
    List<String>? subjects,
    DateTime? dateOfBirth,
    bool? parentalConsentGiven,
  }) async {
    if (_userModel == null) return;

    try {
      _setLoading(true);
      int? gradeInt = int.tryParse(grade.replaceAll(RegExp(r'[^0-9]'), ''));

      final updates = <String, dynamic>{
        'role': role,
        'grade': gradeInt,
        'schoolName': schoolName,
        'displayName': displayName ?? _userModel!.displayName,
        'phoneNumber': phoneNumber,
        'curriculum': curriculum,
        'educationLevel':
            educationLevel ?? curriculum, // Sync both for compatibility
        'interests': interests,
        'subjects': subjects,
        if (dateOfBirth != null)
          'date_of_birth': dateOfBirth.millisecondsSinceEpoch,
        if (parentalConsentGiven != null)
          'parental_consent_given': parentalConsentGiven,
      };

      updates.removeWhere((key, value) => value == null);

      await _authService.firestore
          .collection('users')
          .doc(_userModel!.uid)
          .update(updates);

      _userModel = _userModel!.copyWith(
        role: role,
        grade: gradeInt,
        schoolName: schoolName,
        displayName: displayName,
        phoneNumber: phoneNumber,
        curriculum: curriculum,
        educationLevel: educationLevel ?? _userModel!.educationLevel,
        interests: interests,
        subjects: subjects,
        dateOfBirth: dateOfBirth,
        parentalConsentGiven: parentalConsentGiven,
      );

      notifyListeners();
    } catch (e) {
      debugPrint("Error updating profile: $e");
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
    _userModel = null;
    _isGuest = false;
    _requiresEmailVerification = false;
    _guestMessageCount = 0;
    _guestDocumentCount = 0;
    notifyListeners();
  }

  Future<void> updateLanguage(String lang) async {
    if (_userModel == null) return;
    await _authService.firestore
        .collection('users')
        .doc(_userModel!.uid)
        .update({'preferred_language': lang});
    _userModel = _userModel!.copyWith(preferredLanguage: lang);
    notifyListeners();
  }

  /// Delete account and all associated data (Kenya DPA 2019 Section 40 - Right to Erasure)
  Future<void> deleteAccount() async {
    if (_userModel == null) return;
    try {
      final uid = _userModel!.uid;
      final firestore = _authService.firestore;

      // Delete user's support tickets
      final tickets = await firestore
          .collection('support_tickets')
          .where('userId', isEqualTo: uid)
          .get();
      for (final doc in tickets.docs) {
        await doc.reference.delete();
      }

      // Delete user's activity records
      final activities = await firestore
          .collection('user_activity')
          .where('userId', isEqualTo: uid)
          .get();
      for (final doc in activities.docs) {
        await doc.reference.delete();
      }

      // Delete user profile document
      await firestore.collection('users').doc(uid).delete();

      // Delete Firebase Auth account
      await _authService.deleteAccount();
      _userModel = null;
      notifyListeners();
    } catch (e) {
      debugPrint("Delete Account Error: $e");
      rethrow;
    }
  }

  Future<void> updateSubscription(int durationInDays) async {
    if (_userModel == null) return;
    final expiry = DateTime.now().add(Duration(days: durationInDays));

    await _authService.firestore
        .collection('users')
        .doc(_userModel!.uid)
        .update({
      'isSubscribed': true,
      'subscriptionExpiry': Timestamp.fromDate(expiry),
    });

    _userModel = _userModel!.copyWith(
      isSubscribed: true,
      subscriptionExpiry: expiry,
    );
    notifyListeners();
  }

  Future<void> reloadUser() async {
    User? user = _authService.currentUser;
    if (user != null) {
      await user.reload();
      user = _authService.currentUser;
      if (user == null || !user.emailVerified) {
        _requiresEmailVerification = user != null;
        _userModel = null;
        notifyListeners();
        return;
      }
      _requiresEmailVerification = false;
      await _ensureUserProfile(user);
      notifyListeners();
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  String _generateLinkCode() {
    // Generate a 6-char code (simple timestamp-based for now)
    return DateTime.now().millisecondsSinceEpoch.toString().substring(7);
  }
}
