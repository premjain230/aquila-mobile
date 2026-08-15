import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fa;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_config.dart';
import '../models/aquila_user.dart';

/// Email/password + Google auth, mirroring the web `auth.js` flow:
/// sign up → create user doc → send verification email → wait for
/// verification (verify-email screen) → app.
class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  final fa.FirebaseAuth _auth = fa.FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final GoogleSignIn _google = GoogleSignIn();

  Stream<fa.User?> get authState => _auth.authStateChanges();

  fa.User? get currentUser => _auth.currentUser;

  bool get isEmailVerified => _auth.currentUser?.emailVerified ?? false;

  Stream<fa.User?> reloadOnAuth() async* {
    await for (final u in _auth.authStateChanges()) {
      if (u != null) await u.reload();
      yield u;
    }
  }

  Future<void> signUp({
    required String name,
    required String email,
    required String password,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final user = cred.user;
    if (user == null) throw Exception('Account created but no session');
    await user.updateDisplayName(name.trim());
    await _ensureUserDoc(user, displayName: name.trim());
    await _maybeApplyReferral(user);
    await user.sendEmailVerification();
  }

  Future<void> login(String email, String password) async {
    await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<fa.User?> signInWithGoogle() async {
    final account = await _google.signIn();
    if (account == null) return _auth.currentUser;
    final googleAuth = await account.authentication;
    final credential = fa.GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    try {
      final result = await _auth.signInWithCredential(credential);
      final user = result.user;
      if (user != null) {
        await _ensureUserDoc(user, displayName: user.displayName);
      }
      return user;
    } on fa.FirebaseAuthException catch (e) {
      if (e.code == 'account-exists-with-different-credential') {
        throw Exception(
            'An account already exists with this email. Sign in with your existing method instead.');
      }
      rethrow;
    }
  }

  /// Creates (or refreshes) the `users/{uid}` document with defaults that
  /// match the web `ensureUserDoc`.
  Future<void> _ensureUserDoc(fa.User user, {String? displayName}) async {
    final ref = _db.collection('users').doc(user.uid);
    final existing = await ref.get();
    if (existing.exists) {
      final patch = <String, dynamic>{'updatedAt': FieldValue.serverTimestamp()};
      if (displayName != null && displayName.isNotEmpty) {
        patch['displayName'] = displayName;
      }
      await ref.set(patch, SetOptions(merge: true));
      return;
    }
    await ref.set({
      'uid': user.uid,
      'email': user.email ?? '',
      'displayName': displayName ?? user.displayName ?? '',
      'photoURL': user.photoURL ?? '',
      'plan': 'free',
      'streak': 0,
      'topics': [],
      'personality': '',
      'futureMeLetter': '',
      'referralCode': _generateReferralCode(),
      'referralEarnings': 0,
      'referralCount': 0,
      'referralTiers': {},
      'onboardingComplete': false,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _maybeApplyReferral(fa.User user) async {
    final prefs = await SharedPreferences.getInstance();
    final refCode = prefs.getString(AppConfig.prefReferred);
    if (refCode == null || refCode.isEmpty) return;
    try {
      await ApiCaller.post('${AppConfig.referralPath}?path=claim', {
        'code': refCode,
        'referredUid': user.uid,
      });
    } catch (_) {
      // Referral claim is best-effort; never block sign-up on it.
    }
  }

  String _generateReferralCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random();
    var code = 'AQ';
    for (var i = 0; i < 6; i++) {
      code += chars[random.nextInt(chars.length)];
    }
    return code;
  }

  /// Streams the user document as an [AquilaUser].
  Stream<AquilaUser?> userStream(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((snap) => snap.exists ? AquilaUser.fromMap(uid, snap.data()!) : null);
  }

  Future<AquilaUser?> userOnce(String uid) async {
    final snap = await _db.collection('users').doc(uid).get();
    return snap.exists ? AquilaUser.fromMap(uid, snap.data()!) : null;
  }

  /// Marks onboarding as complete once the planner is configured.
  Future<void> completeOnboarding(String uid) async {
    await _db.collection('users').doc(uid).set(
      {'onboardingComplete': true, 'updatedAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
  }

  Future<void> updatePersonality(String uid, String personality) async {
    await _db.collection('users').doc(uid).set(
      {'personality': personality, 'updatedAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
  }
}

/// Minimal bearer-post helper for the referral claim (kept out of the API
/// client to avoid a circular import; mirrors web referral flow).
class ApiCaller {
  static Future<void> post(String path, Map<String, dynamic> body) async {
    final idToken = await fa.FirebaseAuth.instance.currentUser?.getIdToken();
    final resp = await http.post(
      Uri.parse(AppConfig.api(path)),
      headers: {
        'Content-Type': 'application/json',
        if (idToken != null) 'Authorization': 'Bearer $idToken',
      },
      body: jsonEncode(body),
    );
    if (resp.statusCode >= 400) {
      throw Exception('Request failed (HTTP ${resp.statusCode})');
    }
  }
}