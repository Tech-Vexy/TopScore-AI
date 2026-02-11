import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService {
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

  GoogleSignIn get googleSignIn => _googleSignIn;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<void> _ensureGoogleSignInInitialized() async {
    if (!_googleSignInInitialized) {
      await _googleSignIn.initialize();
      _googleSignInInitialized = true;
    }
  }

  Future<User?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        // On web, use Firebase Auth directly
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        final UserCredential userCredential = await _auth.signInWithPopup(googleProvider);
        return userCredential.user;
      } else {
        // On mobile, use google_sign_in package
        await _ensureGoogleSignInInitialized();
        
        final GoogleSignInAccount googleUser = await _googleSignIn.authenticate(
          scopeHint: <String>['email'],
        );
        
        // Get authentication details
        final GoogleSignInAuthentication googleAuth = googleUser.authentication;
        
        // Create credential
        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: null,
          idToken: googleAuth.idToken,
        );

        final UserCredential userCredential = await _auth.signInWithCredential(
          credential,
        );
        return userCredential.user;
      }
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        debugPrint('Google Sign In Error: User cancelled sign in');
      } else {
        debugPrint('Google Sign In Error: $e');
      }
      return null;
    } catch (e) {
      debugPrint('Google Sign In Error: $e');
      return null;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user != null) {
      await user.delete();
    }
  }

  Future<UserModel?> getUserProfile(String uid) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(uid)
          .get();
      if (doc.exists) {
        return UserModel.fromMap(doc.data() as Map<String, dynamic>, uid);
      }
      return null;
    } catch (e) {
      debugPrint('$e');
      return null;
    }
  }

  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .set(data, SetOptions(merge: true));
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

  Future<UserCredential?> signInWithEmail(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } catch (e) {
      debugPrint('$e');
      rethrow;
    }
  }

  Future<UserCredential?> signUpWithEmail(String email, String password) async {
    try {
      await _ensureBlockedEmailDomainsLoaded();
      if (_isEmailDomainBlocked(email)) {
        throw Exception(
            'Disposable or fraudulent email providers are not allowed.');
      }
      return await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } catch (e) {
      debugPrint('$e');
      rethrow;
    }
  }

  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }
}
