import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class AuthProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  UserModel? _userModel;
  UserModel? get userModel => _userModel;

  bool _isLoading = true; // Start as true until init() completes
  bool get isLoading => _isLoading;

  // Guest Mode logic
  String? _guestId;
  String get effectiveUserId =>
      _userModel?.uid ?? _auth.currentUser?.uid ?? _guestId ?? 'guest';

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
    try {
      _setLoading(true);
      final user = _auth.currentUser;
      if (user == null) {
        await _auth.signInAnonymously();
        debugPrint('Signed in anonymously as guest');
      }
      _isGuest = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Anonymous sign-in error: $e');
      // Fall back to local guest mode if anonymous auth fails
      _isGuest = true;
      notifyListeners();
    } finally {
      _setLoading(false);
    }
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
      // Initialize persistent guest ID
      final prefs = await SharedPreferences.getInstance();
      _guestId = prefs.getString('local_guest_id');
      if (_guestId == null) {
        _guestId = 'guest_${const Uuid().v4()}';
        await prefs.setString('local_guest_id', _guestId!);
      }

      User? user = _auth.currentUser;
      if (user != null) {
        await user.reload();
        user = _auth.currentUser;
        DocumentSnapshot doc = await _firestore
            .collection('users')
            .doc(user!.uid)
            .get();
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
      notifyListeners(); // Ensure listeners know about the guest ID
    }
  }

  // --- GOOGLE SIGN IN ---

  /// Helper to call backend migration endpoint
  Future<void> _migrateAnonymousData(String fromUid, String toUid) async {
    if (fromUid == toUid) return;
    try {
      debugPrint("Migrating data from $fromUid to $toUid...");
      final backendUrl = _getBackendUrl();
      await http.post(
        Uri.parse('$backendUrl/api/migrate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'from_user_id': fromUid, 'to_user_id': toUid}),
      );
      debugPrint("Migration request sent.");
    } catch (e) {
      debugPrint("Migration failed: $e");
    }
  }

  String _getBackendUrl() {
    // Simplified for now, usually stored in config.
    // Assuming localhost for Android/Emulator or Web logic from ChatScreen
    // For this provider, we might default to the deployed URL or logic similar to ChatScreen
    return 'https://agent.topscoreapp.ai';
  }

  // --- GOOGLE SIGN IN ---

  Future<bool> signInWithGoogle() async {
    try {
      _setLoading(true);

      final account = await _googleSignIn.signIn();
      if (account == null) {
        _setLoading(false);
        return false;
      }

      final GoogleSignInAuthentication authentication =
          await account.authentication;

      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: authentication.accessToken,
        idToken: authentication.idToken,
      );

      final currentUser = _auth.currentUser;
      String? anonUid;
      if (currentUser != null && currentUser.isAnonymous) {
        anonUid = currentUser.uid;
      }

      UserCredential userCredential;

      if (currentUser != null && currentUser.isAnonymous) {
        try {
          // Try to link first (Preferred: Keeps UID same)
          userCredential = await currentUser.linkWithCredential(credential);
          debugPrint("Successfully linked anonymous account to Google.");
        } on FirebaseAuthException catch (e) {
          if (e.code == 'credential-already-in-use') {
            // Context: Account exists. We must switch to it.
            // But we lose the anonymous UID session. We MUST migrate.
            debugPrint("Credential in use, switching and migrating...");
            userCredential = await _auth.signInWithCredential(credential);

            // Trigger Backend Migration
            if (anonUid != null && userCredential.user != null) {
              await _migrateAnonymousData(anonUid, userCredential.user!.uid);
            }
          } else {
            rethrow;
          }
        }
      } else {
        // Standard ID
        userCredential = await _auth.signInWithCredential(credential);
      }

      User? user = userCredential.user;

      if (user != null) {
        // ... (Existing logic for fetching/creating user doc) ...
        DocumentSnapshot doc = await _firestore
            .collection('users')
            .doc(user.uid)
            .get();

        if (doc.exists) {
          _userModel = UserModel.fromMap(
            doc.data() as Map<String, dynamic>,
            user.uid,
          );
          notifyListeners();
          _setLoading(false);
          return true;
        } else {
          UserModel newUser = UserModel(
            uid: user.uid,
            email: user.email ?? '',
            displayName: user.displayName ?? 'New User',
            photoURL: user.photoURL,
            role: '',
            grade: null,
            schoolName: '',
          );

          await _firestore
              .collection('users')
              .doc(user.uid)
              .set(newUser.toMap());
          _userModel = newUser;

          notifyListeners();
          _setLoading(false);
          return true;
        }
      }
    } catch (e) {
      debugPrint("Google Sign In Error: $e");
      _setLoading(false);
      rethrow;
    }
    _setLoading(false);
    return false;
  }

  // --- EMAIL AND PASSWORD AUTH ---

  Future<bool> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      _setLoading(true);

      UserCredential userCredential;
      final currentUser = _auth.currentUser;

      // If anonymous, try to link first to preserve UID
      if (currentUser != null && currentUser.isAnonymous) {
        try {
          final credential = EmailAuthProvider.credential(
            email: email,
            password: password,
          );
          userCredential = await currentUser.linkWithCredential(credential);
        } on FirebaseAuthException catch (e) {
          // If email already in use, we can't link.
          // We shouldn't switch automatically because that's a Sign In flow.
          // We just let it fail or handle specifically.
          // For now, fall back to standard create (will fail with email-already-in-use)
          if (e.code == 'email-already-in-use') {
            rethrow;
          }
          // Fallback
          userCredential = await _auth.createUserWithEmailAndPassword(
            email: email,
            password: password,
          );
        }
      } else {
        userCredential = await _auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
      }

      User? user = userCredential.user;
      if (user != null) {
        await user.updateDisplayName(displayName);

        // Standard Firestore creation logic
        UserModel newUser = UserModel(
          uid: user.uid,
          email: email,
          displayName: displayName,
          role: 'student',
          schoolName: '',
          grade: null,
          isSubscribed: false,
          xp: 0,
          level: 1,
          badges: [],
        );

        // Use Set (merge to be safe if checking existingdoc, but usually new)
        await _firestore.collection('users').doc(user.uid).set(newUser.toMap());
        _userModel = newUser;

        // Verify email?
        try {
          await user.sendEmailVerification();
        } catch (_) {}

        notifyListeners();
        return true;
      }
    } on FirebaseAuthException catch (e) {
      debugPrint("Sign Up Error: ${e.code} - ${e.message}");
      rethrow;
    } finally {
      _setLoading(false);
    }
    return false;
  }

  Future<bool> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      _setLoading(true);

      final currentUser = _auth.currentUser;
      String? anonUid;
      if (currentUser != null && currentUser.isAnonymous) {
        anonUid = currentUser.uid;
      }

      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = userCredential.user;
      if (user != null) {
        // Migration Check
        if (anonUid != null) {
          await _migrateAnonymousData(anonUid, user.uid);
        }

        // Reload user to get latest verification status
        await user.reload();

        DocumentSnapshot doc = await _firestore
            .collection('users')
            .doc(user.uid)
            .get();
        if (doc.exists) {
          _userModel = UserModel.fromMap(
            doc.data() as Map<String, dynamic>,
            user.uid,
          );
          notifyListeners();
          return true;
        }
      }
    } on FirebaseAuthException catch (e) {
      debugPrint("Sign In Error: ${e.code} - ${e.message}");
      rethrow;
    } finally {
      _setLoading(false);
    }
    return false;
  }

  /// Generic signIn method that delegates to signInWithEmail
  Future<void> signIn(String email, String password) async {
    await signInWithEmail(email: email, password: password);
  }

  Future<void> sendEmailVerification() async {
    try {
      User? user = _auth.currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
      }
    } catch (e) {
      debugPrint("Error sending verification email: $e");
      rethrow;
    }
  }

  bool get isEmailVerified {
    return _auth.currentUser?.emailVerified ?? false;
  }

  /// Password validation logic
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 8) {
      return 'Password must be at least 8 characters long';
    }
    if (!value.contains(RegExp(r'[A-Z]'))) {
      return 'Password must contain at least one uppercase letter';
    }
    if (!value.contains(RegExp(r'[a-z]'))) {
      return 'Password must contain at least one lowercase letter';
    }
    if (!value.contains(RegExp(r'[0-9]'))) {
      return 'Password must contain at least one number';
    }
    if (!value.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      return 'Password must contain at least one special character';
    }
    return null;
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
    _userModel = null;
    _isGuest = false;
    _guestMessageCount = 0;
    _guestDocumentCount = 0;
    notifyListeners();
  }

  // --- MISSING METHODS ---

  // --- ADDITIONAL AUTH METHODS ---

  /// Clears the current anonymous session effectively "resetting" the guest user.
  /// Useful for shared devices.
  Future<void> clearGuestSession() async {
    try {
      final user = _auth.currentUser;
      if (user != null && user.isAnonymous) {
        await user.delete(); // Removes the anonymous UID from Firebase Auth
      }
      await signOut(); // Clears local state
      await continueAsGuest(); // Starts a fresh anonymous session
    } catch (e) {
      debugPrint("Error clearing guest session: $e");
      await signOut();
      await continueAsGuest();
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
    _userModel = _userModel!.copyWith(
      isSubscribed: true,
      subscriptionExpiry: expiry,
    );
    notifyListeners();
  }

  Future<void> reloadUser() async {
    User? user = _auth.currentUser;
    if (user != null) {
      await user.reload();
      DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists) {
        _userModel = UserModel.fromMap(
          doc.data() as Map<String, dynamic>,
          user.uid,
        );
        notifyListeners();
      }
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
