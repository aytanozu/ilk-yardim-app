import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/location/background_service_runner.dart';
import '../../../core/notifications/fcm_service.dart';
import '../../../core/observability/breadcrumbs.dart';
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

  void _transitionStage(AuthStage next) {
    if (_stage == next) return;
    breadcrumb('auth_stage', {'from': _stage.name, 'to': next.name});
    setCustomKey('auth_stage', next.name);
    _stage = next;
  }

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
        _transitionStage(AuthStage.phoneEntry);
      }
      BackgroundServiceRunner.instance.stop();
      _clearCrashlyticsUser();
    } else {
      _profileSub?.cancel();
      _profileSub = _repo.watchProfile(user.uid).listen((p) {
        _profile = p;
        if (p != null && _stage != AuthStage.authenticated) {
          _transitionStage(AuthStage.authenticated);
        }
        notifyListeners();
      });
      FcmService.instance.registerForCurrentUser();
      _ensureLocationAndStartService();
      _setCrashlyticsUser(user.uid);
    }
    notifyListeners();
  }

  void _setCrashlyticsUser(String uid) {
    try {
      FirebaseCrashlytics.instance.setUserIdentifier(uid);
    } catch (_) {
      // Crashlytics unavailable (e.g., web or uninitialized). Non-fatal.
    }
  }

  void _clearCrashlyticsUser() {
    try {
      FirebaseCrashlytics.instance.setUserIdentifier('');
    } catch (_) {}
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
      _transitionStage(AuthStage.notCertified);
      _notCertifiedReason = check.reason;
      notifyListeners();
      return;
    }

    _transitionStage(AuthStage.awaitingCode);
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
        _transitionStage(AuthStage.phoneEntry);
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
      _transitionStage(AuthStage.finalizing);
      notifyListeners();
      await _repo.confirmOtp(
        verificationId: _verificationId!,
        smsCode: code,
      );
      await _finalize();
    } catch (e) {
      _lastError = 'Kod doğrulanamadı';
      _transitionStage(AuthStage.awaitingCode);
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
    _transitionStage(AuthStage.phoneEntry);
    notifyListeners();
  }

  Future<void> signOut() async {
    // Clean up this device's FCM token from the user's doc BEFORE we
    // lose the auth context — otherwise the next user on this device
    // could receive pushes addressed to the previous user's tokens.
    await _cleanupFcmToken();
    await _repo.signOut();
  }

  Future<void> _cleanupFcmToken() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).set(
          {
            'fcmTokens': FieldValue.arrayRemove([token]),
          },
          SetOptions(merge: true),
        );
      }
      await FirebaseMessaging.instance.deleteToken();
    } catch (e) {
      // Firebase uninitialized (unit tests, web without plugin) — treat
      // as best-effort and let signOut continue.
      debugPrint('fcm token cleanup on signOut skipped: $e');
    }
  }

  /// Toggle whether this volunteer is available to receive wave pushes.
  /// Written to users/{uid}.available; the `onEmergencyCreate` function
  /// filters recipients on this field.
  Future<void> setAvailable(bool value) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance.collection('users').doc(uid).set(
      {
        'available': value,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  /// Update the volunteer's notification preferences.
  Future<void> updateNotificationPrefs({required bool criticalOnly}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance.collection('users').doc(uid).set(
      {
        'notificationPrefs': {'criticalOnly': criticalOnly},
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  /// Save profile edits (name, region).
  Future<void> updateProfile({
    String? fullName,
    Map<String, dynamic>? region,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final update = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (fullName != null) update['fullName'] = fullName;
    if (region != null) update['region'] = region;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .set(update, SetOptions(merge: true));
  }

  @override
  void dispose() {
    _sub?.cancel();
    _profileSub?.cancel();
    super.dispose();
  }
}
