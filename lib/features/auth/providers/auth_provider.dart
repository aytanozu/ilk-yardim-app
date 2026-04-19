import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/location/background_service_runner.dart';
import '../../../core/notifications/fcm_service.dart';
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
      BackgroundServiceRunner.instance.stop();
    } else {
      _profileSub?.cancel();
      _profileSub = _repo.watchProfile(user.uid).listen((p) {
        _profile = p;
        if (p != null && _stage != AuthStage.authenticated) {
          _stage = AuthStage.authenticated;
        }
        notifyListeners();
      });
      FcmService.instance.registerForCurrentUser();
      _ensureLocationAndStartService();
    }
    notifyListeners();
  }

  /// Requests location permission up to "Always" then boots the native
  /// foreground service so tracking persists across app-kill / reboot.
  Future<void> _ensureLocationAndStartService() async {
    debugPrint('[bgservice] ensureLocationAndStartService entered');
    try {
      // Use permission_handler (awaits the dialog reliably, unlike some
      // Geolocator builds on Android 15 emulator which never resolve).
      var status = await Permission.location.status;
      debugPrint('[bgservice] initial location status=$status');
      if (!status.isGranted) {
        status = await Permission.location.request();
        debugPrint('[bgservice] after request location status=$status');
      }
      if (!status.isGranted) {
        debugPrint('[bgservice] location NOT granted — skipping service start');
        return;
      }
      // Try to upgrade to Always (background). Android shows a second dialog
      // only if foreground is already granted.
      if (!await Permission.locationAlways.isGranted) {
        final bg = await Permission.locationAlways.request();
        debugPrint('[bgservice] locationAlways status=$bg');
      }

      debugPrint('[bgservice] calling start()');
      await BackgroundServiceRunner.instance.start();
    } catch (e, s) {
      debugPrint('[bgservice] ensureLocationAndStartService EXCEPTION: $e\n$s');
    }
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
