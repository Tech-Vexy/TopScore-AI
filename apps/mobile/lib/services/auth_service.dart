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
  FirebaseAuth get auth => _auth;
  FirebaseFirestore get firestore => _firestore;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<void> ensureBlockedEmailDomainsLoaded() async {
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

  bool isEmailDomainBlocked(String email) {
    final domain = email.split('@').last.toLowerCase().trim();
    if (domain.isEmpty) return true;
    return _blockedEmailDomains.contains(domain);
  }

  Future<void> _ensureGoogleSignInInitialized() async {
    if (!_googleSignInInitialized) {
      await _googleSignIn.initialize();
      _googleSignInInitialized = true;
    }
  }

  Future<User?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        final UserCredential userCredential =
            await _auth.signInWithPopup(googleProvider);
        return userCredential.user;
      } else {
        await _ensureGoogleSignInInitialized();

        final GoogleSignInAccount googleUser = await _googleSignIn.authenticate(
          scopeHint: <String>['email'],
        );

        final GoogleSignInAuthentication googleAuth = googleUser.authentication;

        final OAuthCredential credential = GoogleAuthProvider.credential(
          accessToken: null,
          idToken: googleAuth.idToken,
        );

        // Check for anonymous user upgrade
        final currentUser = _auth.currentUser;
        UserCredential userCredential;

        if (currentUser != null && currentUser.isAnonymous) {
          try {
            userCredential = await currentUser.linkWithCredential(credential);
          } on FirebaseAuthException catch (e) {
            if (e.code == 'credential-already-in-use') {
              userCredential = await _auth.signInWithCredential(credential);
            } else {
              rethrow;
            }
          }
        } else {
          userCredential = await _auth.signInWithCredential(credential);
        }

        return userCredential.user;
      }
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        debugPrint('Google Sign In: User cancelled');
        return null;
      }
      rethrow;
    } catch (e) {
      debugPrint('Google Sign In Error: $e');
      rethrow;
    }
  }

  Future<UserCredential?> signInWithEmail(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<UserCredential?> signUpWithEmail(String email, String password) async {
    await ensureBlockedEmailDomainsLoaded();
    if (isEmailDomainBlocked(email)) {
      throw Exception(
          'Disposable or fraudulent email providers are not allowed.');
    }
    return await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> signOut() async {
    try {
      // Only sign out from Google if it was initialized in this session.
      // This prevents "Bad state" errors on Web where the plugin may not be initialized.
      if (_googleSignInInitialized) {
        await _googleSignIn.signOut();
      }
    } catch (e) {
      debugPrint(
          'Google Sign Out error (safe to ignore if not initialized): $e');
    } finally {
      await _auth.signOut();
      _googleSignInInitialized = false;
    }
  }

  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user != null) {
      await user.delete();
    }
  }

  Future<UserModel?> getUserProfile(String uid) async {
    try {
      DocumentSnapshot doc =
          await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return UserModel.fromMap(doc.data() as Map<String, dynamic>, uid);
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching user profile: $e');
      return null;
    }
  }

  Future<void> updateUserProfile(String uid, Map<String, dynamic> data) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .set(data, SetOptions(merge: true));
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
