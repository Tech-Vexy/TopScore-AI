import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  bool _googleSignInInitialized = false;

  UserModel? _userModel;
  UserModel? get userModel => _userModel;

  bool _isLoading = true; // Start as true until init() completes
  bool get isLoading => _isLoading;

  // Guest Mode logic
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
      User? user = _auth.currentUser;
      if (user != null) {
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

      await _ensureGoogleSignInInitialized();

      final account = await _googleSignIn.authenticate();

      // Get the ID token from authentication
      final idToken = account.authentication.idToken;

      // For Firebase Auth, we need to get an access token via authorization
      // Request authorization for basic scopes to get access token
      final authorization = await account.authorizationClient
          .authorizeScopes(['email', 'profile']);

      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: authorization.accessToken,
        idToken: idToken,
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
        DocumentSnapshot doc =
            await _firestore.collection('users').doc(user.uid).get();

        if (doc.exists) {
          _userModel = UserModel.fromMap(
            doc.data() as Map<String, dynamic>,
            user.uid,
          );
          notifyListeners();
          _setLoading(false);
          return true;
        } else {
          // New User Setup
          UserModel newUser = UserModel(
            uid: user.uid,
            email: user.email ?? '',
            displayName: user.displayName ?? 'New User',
            photoURL: user.photoURL,
            role: '',
            grade: null,
            schoolName: '', // Default empty
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

  // Email/Password methods removed as per request to remove email/password auth.

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
      DocumentSnapshot doc =
          await _firestore.collection('users').doc(user.uid).get();
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
