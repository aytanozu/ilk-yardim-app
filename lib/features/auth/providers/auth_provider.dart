import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../../shared/models/user_profile.dart';
import '../data/auth_repo.dart';

enum AuthStage {
  unknown,
  notCertified,
  phoneEntry,
  awaitingCode,
  finalizing,
  authenticated,
}

class AuthProvider extends ChangeNotifier {
  AuthProvider({AuthRepo? repo}) : _repo = repo ?? AuthRepo() {
    _sub = _repo.authStateChanges().listen(_onAuthStateChange);
  }

  final AuthRepo _repo;
  StreamSubscription<User?>? _sub;
  StreamSubscription<UserProfile?>? _profileSub;

  AuthStage _stage = AuthStage.unknown;
  String? _phoneE164;
  String? _verificationId;
  String? _lastError;
  UserProfile? _profile;
  String? _notCertifiedReason;

  AuthStage get stage => _stage;
  String? get phoneE164 => _phoneE164;
  String? get lastError => _lastError;
  UserProfile? get profile => _profile;
  String? get notCertifiedReason => _notCertifiedReason;

  void _onAuthStateChange(User? user) {
    if (user == null) {
      _profileSub?.cancel();
      _profileSub = null;
      _profile = null;
      if (_stage != AuthStage.awaitingCode &&
          _stage != AuthStage.notCertified) {
        _stage = AuthStage.phoneEntry;
      }
    } else {
      _profileSub?.cancel();
      _profileSub = _repo.watchProfile(user.uid).listen((p) {
        _profile = p;
        if (p != null && _stage != AuthStage.authenticated) {
          _stage = AuthStage.authenticated;
        }
        notifyListeners();
      });
    }
    notifyListeners();
  }

  Future<void> submitPhone(String phoneE164) async {
    _lastError = null;
    _phoneE164 = phoneE164;
    final check = await _repo.checkCertified(phoneE164);
    if (!check.ok) {
      _stage = AuthStage.notCertified;
      _notCertifiedReason = check.reason;
      notifyListeners();
      return;
    }

    _stage = AuthStage.awaitingCode;
    notifyListeners();

    await _repo.startPhoneVerification(
      phoneE164: phoneE164,
      onCodeSent: (id) {
        _verificationId = id;
        notifyListeners();
      },
      onAutoVerified: _finalize,
      onError: (msg) {
        _lastError = msg;
        _stage = AuthStage.phoneEntry;
        notifyListeners();
      },
    );
  }

  Future<void> submitOtp(String code) async {
    if (_verificationId == null) {
      _lastError = 'Doğrulama kodu beklenemedi';
      notifyListeners();
      return;
    }
    try {
      _stage = AuthStage.finalizing;
      notifyListeners();
      await _repo.confirmOtp(
        verificationId: _verificationId!,
        smsCode: code,
      );
      await _finalize();
    } catch (e) {
      _lastError = 'Kod doğrulanamadı';
      _stage = AuthStage.awaitingCode;
      notifyListeners();
    }
  }

  Future<void> _finalize() async {
    try {
      await _repo.finalizeSignup();
      // Force ID token refresh so custom claim arrives
      await FirebaseAuth.instance.currentUser?.getIdToken(true);
    } catch (e) {
      debugPrint('finalize error: $e');
    }
  }

  void resetToPhoneEntry() {
    _lastError = null;
    _notCertifiedReason = null;
    _verificationId = null;
    _stage = AuthStage.phoneEntry;
    notifyListeners();
  }

  Future<void> signOut() async {
    await _repo.signOut();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _profileSub?.cancel();
    super.dispose();
  }
}
