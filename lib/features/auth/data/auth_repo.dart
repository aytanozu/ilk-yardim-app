import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../../shared/models/user_profile.dart';

class CertifiedCheckResult {
  CertifiedCheckResult({required this.ok, this.reason});
  final bool ok;
  final String? reason;
}

class AuthRepo {
  AuthRepo({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ??
            FirebaseFunctions.instanceFor(region: 'europe-west3');

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  Stream<User?> authStateChanges() => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<CertifiedCheckResult> checkCertified(String phoneE164) async {
    try {
      final res = await _functions
          .httpsCallable('checkCertifiedPhone')
          .call<Map<String, dynamic>>({'phoneE164': phoneE164});
      final data = res.data;
      return CertifiedCheckResult(
        ok: data['ok'] as bool? ?? false,
        reason: data['reason'] as String?,
      );
    } catch (e) {
      debugPrint('checkCertifiedPhone error: $e');
      return CertifiedCheckResult(ok: false, reason: 'network');
    }
  }

  /// Starts phone verification. Returns the verificationId via [onCodeSent].
  Future<void> startPhoneVerification({
    required String phoneE164,
    required void Function(String verificationId) onCodeSent,
    required void Function(String message) onError,
    required void Function() onAutoVerified,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneE164,
      timeout: timeout,
      verificationCompleted: (credential) async {
        await _auth.signInWithCredential(credential);
        onAutoVerified();
      },
      verificationFailed: (e) => onError(e.message ?? 'Doğrulama başarısız'),
      codeSent: (verificationId, _) => onCodeSent(verificationId),
      codeAutoRetrievalTimeout: (_) {},
    );
  }

  Future<void> confirmOtp({
    required String verificationId,
    required String smsCode,
  }) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    await _auth.signInWithCredential(credential);
  }

  Future<void> finalizeSignup() async {
    await _functions
        .httpsCallable('finalizeSignup')
        .call<Map<String, dynamic>>();
  }

  Future<UserProfile?> loadProfile(String uid) async {
    final snap = await _firestore.collection('users').doc(uid).get();
    if (!snap.exists) return null;
    return UserProfile.fromSnapshot(snap);
  }

  Stream<UserProfile?> watchProfile(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((s) => s.exists ? UserProfile.fromSnapshot(s) : null);
  }

  Future<void> signOut() => _auth.signOut();
}
