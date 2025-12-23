import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../models/user_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:google_sign_in/google_sign_in.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();

  UserModel? _userModel;
  bool _isLoading = false;
  bool _needsRoleSelection = false;

  UserModel? get userModel => _userModel;
  bool get isLoading => _isLoading;
  bool get needsRoleSelection => _needsRoleSelection;
  GoogleSignIn get googleSignIn => _authService.googleSignIn;

  // Initialize auth state
  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Listen to auth state changes
      _authService.authStateChanges.listen((User? user) async {
        debugPrint("Auth state changed: ${user?.uid}");
        if (user != null) {
          await _fetchUserData(user.uid);
          if (_userModel == null) {
            _needsRoleSelection = true;
          }
        } else {
          _userModel = null;
          _needsRoleSelection = false;
        }
        notifyListeners();
      });

      User? firebaseUser = _authService.currentUser;
      if (firebaseUser != null) {
        await _fetchUserData(firebaseUser.uid);
        if (_userModel == null) {
          _needsRoleSelection = true;
        }
      }
    } catch (e) {
      debugPrint("Error during auth initialization: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _fetchUserData(String uid) async {
    try {
      debugPrint("Fetching user data for UID: $uid");
      _userModel = await _firestoreService.getUser(uid);
      debugPrint("User data fetched: ${_userModel?.toString()}");
    } catch (e) {
      debugPrint("Error fetching user data: $e");
    }
  }

  Future<void> signIn(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      UserCredential? cred = await _authService.signInWithEmail(
        email,
        password,
      );
      if (cred != null && cred.user != null) {
        await _fetchUserData(cred.user!.uid);
      }
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signInWithGoogle() async {
    _isLoading = true;
    notifyListeners();

    try {
      debugPrint("Starting Google Sign In...");
      User? user = await _authService.signInWithGoogle();
      debugPrint("Google Sign In result: ${user?.uid}");

      if (user != null) {
        await _fetchUserData(user.uid);

        if (_userModel == null) {
          debugPrint("User model is null, needs role selection");
          _needsRoleSelection = true;
        } else {
          debugPrint("User model found: ${_userModel?.role}");
        }
      }
    } catch (e) {
      debugPrint("Google Sign In Error: $e");
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> completeGoogleSignup(String role) async {
    _isLoading = true;
    notifyListeners();

    try {
      User? user = _authService.currentUser;
      if (user != null) {
        UserModel newUser = UserModel(
          uid: user.uid,
          email: user.email,
          displayName: user.displayName,
          photoURL: user.photoURL,
          role: role,
        );
        await _firestoreService.createUser(newUser);
        _userModel = newUser;
        _needsRoleSelection = false;
      }
    } catch (e) {
      debugPrint("Error completing signup: $e");
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signUp(
    String email,
    String password,
    String role,
    String name, {
    String? educationLevel,
    int? grade,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      UserCredential? cred = await _authService.signUpWithEmail(
        email,
        password,
      );
      if (cred != null && cred.user != null) {
        UserModel newUser = UserModel(
          uid: cred.user!.uid,
          email: email,
          role: role,
          displayName: name,
          educationLevel: educationLevel,
          grade: grade,
        );
        await _firestoreService.createUser(newUser);
        _userModel = newUser;
      }
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
    _userModel = null;
    notifyListeners();
  }

  Future<void> deleteAccount() async {
    try {
      await _authService.deleteAccount();
      _userModel = null;
      notifyListeners();
    } catch (e) {
      debugPrint("Error deleting account: $e");
      rethrow;
    }
  }

  Future<void> updateSubscription(int days) async {
    if (_userModel == null) return;

    try {
      final expiryDate = DateTime.now().add(Duration(days: days));

      await _firestoreService.updateUserProfile(_userModel!.uid, {
        'isSubscribed': true,
        'subscriptionExpiry': Timestamp.fromDate(expiryDate),
      });

      // Refresh user data
      await _fetchUserData(_userModel!.uid);
    } catch (e) {
      debugPrint("Error updating subscription: $e");
      rethrow;
    }
  }

  Future<void> updateLanguage(String languageCode) async {
    if (_userModel == null) return;

    try {
      await _firestoreService.updateUserProfile(_userModel!.uid, {
        'preferred_language': languageCode,
      });

      // Refresh user data
      await _fetchUserData(_userModel!.uid);
      notifyListeners();
    } catch (e) {
      debugPrint("Error updating language: $e");
      rethrow;
    }
  }
}
