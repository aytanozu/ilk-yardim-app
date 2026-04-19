import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';

class FirebaseBootstrap {
  FirebaseBootstrap._();

  static bool _initialized = false;

  /// Initializes Firebase, App Check, Crashlytics. Safe to call multiple times.
  /// Returns [true] if the real Firebase config was loaded — i.e. the user
  /// ran `flutterfire configure`. When it returns false, the app can still
  /// render but all Firebase-dependent screens should gracefully degrade.
  static Future<bool> init() async {
    if (_initialized) return true;

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (e) {
      debugPrint('Firebase init failed (likely placeholder config): $e');
      return false;
    }

    try {
      await FirebaseAppCheck.instance.activate(
        androidProvider:
            kReleaseMode ? AndroidProvider.playIntegrity : AndroidProvider.debug,
        appleProvider:
            kReleaseMode ? AppleProvider.appAttest : AppleProvider.debug,
      );
    } catch (e) {
      debugPrint('App Check activation failed: $e');
    }

    if (!kIsWeb) {
      FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterError;
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
    }

    _initialized = true;
    return true;
  }

  static bool get isInitialized => _initialized;

  static User? get currentUser =>
      _initialized ? FirebaseAuth.instance.currentUser : null;
}
