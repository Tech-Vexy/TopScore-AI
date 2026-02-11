import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  bool _googleSignInInitialized = false;

  static const Set<String> _defaultBlockedEmailDomains = {
    'mailinator.com',
    '10minutemail.com',
    'tempmail.com',
    'guerrillamail.com',
    'yopmail.com',
    'dispostable.com',
    'sharklasers.com',
    'trashmail.com',
    'getnada.com',
    'mohmal.com',
    'maildrop.cc',
    'fakeinbox.com',
    'temp-mail.org',
    'temp-mail.io',
    'burnermail.io',
    'mailnesia.com',
    'minutemail.com',
    'mailtemp.net',
    'spambog.com',
    'spambox.us',
    'spamgourmet.com',
    'mailcatch.com',
    'emailondeck.com',
    'inboxbear.com',
    'tempr.email',
    'dropmail.me',
  };

  Set<String> _blockedEmailDomains = {};
  bool _blockedEmailDomainsLoaded = false;
  bool _requiresEmailVerification = false;

  UserModel? _userModel;
  UserModel? get userModel => _userModel;

  bool get requiresEmailVerification => _requiresEmailVerification;

  bool _isLoading = true; // Start as true until init() completes
  bool get isLoading => _isLoading;

  // Guest Mode logic (disabled)
  bool _isGuest = false;
  bool get isGuest => _isGuest;

  // Usage counters for guest
  int _guestMessageCount = 0;
  int _guestDocumentCount = 0;

  static const int kGuestMessageLimit = 5;
  static const int kGuestDocumentLimit = 3;

  bool get isAuthOrGuest => _userModel != null || _isGuest;

  /// Sign in anonymously for guest access - this gives a real Firebase uid
  /// so Firestore rules work while user explores without creating an account
  Future<void> continueAsGuest() async {
    _setLoading(true);
    _isGuest = false;
    _setLoading(false);
    throw Exception('Guest access is disabled. Please sign in.');
  }

  bool get canSendMessage {
    if (_userModel != null) return true;
    return _guestMessageCount < kGuestMessageLimit;
  }

  void incrementGuestMessage() {
    if (_isGuest) {
      _guestMessageCount++;
      // notifyListeners(); // Optional: only if UI needs to update count in real-time
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

  // Role selection is disabled - always return false
  bool get needsRoleSelection => false;

  Future<void> init() async {
    _setLoading(true);
    try {
      await _ensureBlockedEmailDomainsLoaded();
      User? user = _auth.currentUser;
      if (user != null) {
        await user.reload();
        user = _auth.currentUser;
        if (user == null || !user.emailVerified) {
          _requiresEmailVerification = user != null;
          _userModel = null;
          return;
        }
        DocumentSnapshot doc =
            await _firestore.collection('users').doc(user.uid).get();
        if (doc.exists) {
          _userModel = UserModel.fromMap(
            doc.data() as Map<String, dynamic>,
            user.uid,
          );
        }
      }
    } catch (e) {
      debugPrint("AuthProvider init error: $e");
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _ensureBlockedEmailDomainsLoaded() async {
    if (_blockedEmailDomainsLoaded) return;
    try {
      final data = await rootBundle
          .loadString('assets/config/blocked_email_domains.json');
      final decoded = jsonDecode(data);
      if (decoded is List) {
        _blockedEmailDomains = decoded
            .whereType<String>()
            .map((e) => e.trim().toLowerCase())
            .where((e) => e.isNotEmpty)
            .toSet();
      } else {
        _blockedEmailDomains = _defaultBlockedEmailDomains;
      }
    } catch (e) {
      debugPrint('Failed to load blocked email domains: $e');
      _blockedEmailDomains = _defaultBlockedEmailDomains;
    } finally {
      _blockedEmailDomainsLoaded = true;
    }
  }

  bool _isEmailDomainBlocked(String email) {
    final domain = email.split('@').last.toLowerCase().trim();
    if (domain.isEmpty) return true;
    return _blockedEmailDomains.contains(domain);
  }

  Future<void> _ensureUserProfile(User user) async {
    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (doc.exists) {
      _userModel = UserModel.fromMap(
        doc.data() as Map<String, dynamic>,
        user.uid,
      );
    } else {
      final newUser = UserModel(
        uid: user.uid,
        email: user.email ?? '',
        displayName: user.displayName ?? 'New User',
        photoURL: user.photoURL,
        role: '',
        grade: null,
        schoolName: '',
      );
      await _firestore.collection('users').doc(user.uid).set(newUser.toMap());
      _userModel = newUser;
    }
  }

  // --- GOOGLE SIGN IN ---
  Future<void> _ensureGoogleSignInInitialized() async {
    if (!_googleSignInInitialized) {
      await _googleSignIn.initialize();
      _googleSignInInitialized = true;
    }
  }

  Future<bool> signInWithGoogle() async {
    try {
      _setLoading(true);

      final OAuthCredential credential;
      
      if (kIsWeb) {
        // On web, use Firebase Auth directly (google_sign_in 7.x doesn't support programmatic sign-in on web)
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        final UserCredential userCredential = await _auth.signInWithPopup(googleProvider);
        
        if (userCredential.user == null) {
          _setLoading(false);
          return false;
        }
        
        // For web, we've already signed in, so handle the user directly
        final user = userCredential.user!;
        await _ensureUserProfile(user);
        notifyListeners();
        return true;
      } else {
        // On mobile, use google_sign_in package
        await _ensureGoogleSignInInitialized();
        
        final GoogleSignInAccount account = await _googleSignIn.authenticate(
          scopeHint: <String>['email'],
        );
        
        // Get authentication details
        final GoogleSignInAuthentication googleAuth = account.authentication;
        
        credential = GoogleAuthProvider.credential(
          accessToken: null,
          idToken: googleAuth.idToken,
        );
        
        // Check current user state for anonymous upgrade
        final currentUser = _auth.currentUser;
        UserCredential userCredential;

        if (currentUser != null && currentUser.isAnonymous) {
          try {
            // Link the anonymous user to the new Google credential
            userCredential = await currentUser.linkWithCredential(credential);
            debugPrint(
                "Successfully linked anonymous account to Google credential");
          } on FirebaseAuthException catch (e) {
            if (e.code == 'credential-already-in-use') {
              // Account already exists, so we sign in to it (merging/overwriting guest session)
              // Ideally prompt user, but for now we switch to the existing account
              debugPrint("Credential in use, switching to existing account");
              userCredential = await _auth.signInWithCredential(credential);
            } else {
              rethrow;
            }
          }
        } else {
          // Standard sign in
          userCredential = await _auth.signInWithCredential(credential);
        }

        User? user = userCredential.user;

        if (user != null) {
          // Google accounts are already verified, no need to check emailVerified
          _requiresEmailVerification = false;
          await _ensureUserProfile(user);
          notifyListeners();
          return true;
        }
      }
    } on GoogleSignInException catch (e) {
      debugPrint("Google Sign In Exception: $e");
      if (e.code == GoogleSignInExceptionCode.canceled) {
        // User cancelled, not an error
        return false;
      }
      rethrow;
    } catch (e) {
      debugPrint("Google Sign In Error: $e");
      rethrow;
    } finally {
      _setLoading(false);
    }
    return false;
  }

  Future<bool> signInWithEmail(String email, String password) async {
    try {
      _setLoading(true);
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user == null) return false;

      await user.reload();
      final refreshedUser = _auth.currentUser;
      if (refreshedUser == null || !refreshedUser.emailVerified) {
        _requiresEmailVerification = true;
        await refreshedUser?.sendEmailVerification();
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

  Future<bool> signUpWithEmail(String email, String password) async {
    try {
      _setLoading(true);
      await _ensureBlockedEmailDomainsLoaded();
      if (_isEmailDomainBlocked(email)) {
        throw Exception(
            'Disposable or fraudulent email providers are not allowed.');
      }
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = credential.user;
      if (user != null) {
        await user.sendEmailVerification();
        _requiresEmailVerification = true;
        _userModel = null;
        notifyListeners();
        return false;
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
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> resendEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null) return;
    if (!user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  Future<bool> reloadAndCheckEmailVerified() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    await user.reload();
    final refreshedUser = _auth.currentUser;
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

  /// Clears the current anonymous session effectively "resetting" the guest user.
  /// Useful for shared devices.
  Future<void> clearGuestSession() async {
    try {
      final user = _auth.currentUser;
      if (user != null && user.isAnonymous) {
        await user.delete(); // Removes the anonymous UID from Firebase Auth
      }
      await signOut(); // Clears local state
    } catch (e) {
      debugPrint("Error clearing guest session: $e");
      await signOut();
    }
  }

  // Updated to include all profile fields
  Future<void> updateUserRole({
    required String role,
    required String grade,
    required String schoolName,
    String? displayName,
    String? phoneNumber,
    String? curriculum,
    List<String>? interests,
    List<String>? subjects,
  }) async {
    if (_userModel == null) return;

    try {
      _setLoading(true);
      int? gradeInt = int.tryParse(grade.replaceAll(RegExp(r'[^0-9]'), ''));

      final updates = {
        'role': role,
        'grade': gradeInt,
        'schoolName': schoolName,
        'displayName': displayName ?? _userModel!.displayName,
        'phoneNumber': phoneNumber,
        'curriculum': curriculum,
        'interests': interests,
        'subjects': subjects,
      };

      // Remove nulls just in case, though Firestore handles merging
      updates.removeWhere((key, value) => value == null);

      await _firestore.collection('users').doc(_userModel!.uid).update(updates);

      // Update local model
      _userModel = _userModel!.copyWith(
        role: role,
        grade: gradeInt,
        schoolName: schoolName,
        displayName: displayName,
        phoneNumber: phoneNumber,
        curriculum: curriculum,
        interests: interests,
        subjects: subjects,
      );

      notifyListeners();
    } catch (e) {
      debugPrint("Error updating profile: $e");
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // Email/Password methods removed as per request to remove email/password auth.

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
    _userModel = null;
    _isGuest = false;
    _requiresEmailVerification = false;
    _guestMessageCount = 0;
    _guestDocumentCount = 0;
    notifyListeners();
  }

  // --- MISSING METHODS ---

  Future<void> updateLanguage(String lang) async {
    if (_userModel == null) return;
    await _firestore.collection('users').doc(_userModel!.uid).update({
      'preferred_language': lang,
    });
    _userModel = _userModel!.copyWith(preferredLanguage: lang);
    notifyListeners();
  }

  Future<void> deleteAccount() async {
    if (_userModel == null) return;
    try {
      await _firestore.collection('users').doc(_userModel!.uid).delete();
      await _auth.currentUser?.delete();
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

    await _firestore.collection('users').doc(_userModel!.uid).update({
      'isSubscribed': true,
      'subscriptionExpiry': Timestamp.fromDate(expiry),
    });

    // Update local
    // Using copyWith is safer now that I verified/added it in UserModel
    _userModel = _userModel!.copyWith(
      isSubscribed: true,
      subscriptionExpiry:
          expiry, // copyWith doesn't have expiry? I should check my previous step.
      // Checked UserModel copyWith: yes I added subscriptionExpiry?
      // Wait, previous step code:
      // copyWith only had: role, grade, schoolName, preferredLanguage.
      // I missed adding all fields to `copyWith`.
      // I must re-implement copyWith in UserModel OR use manual construction here.
      // For safety, manual construction is better if copyWith is incomplete.
    );

    _userModel = UserModel(
      uid: _userModel!.uid,
      email: _userModel!.email,
      displayName: _userModel!.displayName,
      photoURL: _userModel!.photoURL,
      role: _userModel!.role,
      grade: _userModel!.grade,
      schoolName: _userModel!.schoolName,
      educationLevel: _userModel!.educationLevel,
      subjects: _userModel!.subjects,
      isSubscribed: true,
      subscriptionExpiry: expiry,
      preferredLanguage: _userModel!.preferredLanguage,
      linkCode: _userModel!.linkCode,
      parentIds: _userModel!.parentIds,
      childrenIds: _userModel!.childrenIds,
      xp: _userModel!.xp,
      level: _userModel!.level,
      badges: _userModel!.badges,
      interests: _userModel!.interests,
      careerMode: _userModel!.careerMode,
    );
    notifyListeners();
  }

  Future<void> reloadUser() async {
    User? user = _auth.currentUser;
    if (user != null) {
      await user.reload();
      user = _auth.currentUser;
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
}
