import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import '../firebase/emulator_config.dart';

/// Whether we send any breadcrumbs / keys to Crashlytics. Matches the
/// collection gate in FirebaseBootstrap — debug and emulator runs stay
/// noise-free locally but surface detail in production crashes.
bool get _enabled => !kDebugMode && !kUseFirebaseEmulator;

/// Drop a Crashlytics log line describing a user-visible step in the
/// critical flow. Keep messages short and low-cardinality; the log ring
/// buffer is fixed-size, so terse beats verbose.
///
/// Example: `breadcrumb('accept_pressed', {'emergencyId': id});`
void breadcrumb(String key, [Map<String, Object?>? data]) {
  if (!_enabled) return;
  try {
    if (data == null || data.isEmpty) {
      FirebaseCrashlytics.instance.log(key);
    } else {
      final rendered = data.entries
          .map((e) => '${e.key}=${_safe(e.value)}')
          .join(' ');
      FirebaseCrashlytics.instance.log('$key $rendered');
    }
  } catch (_) {
    // Crashlytics unavailable (e.g., web). Never throw from observability.
  }
}

/// Set a long-lived custom key on Crashlytics so crashes are grouped and
/// filtered by it (e.g., current auth stage, active emergency id). These
/// appear in the Crashlytics console under each crash report.
void setCustomKey(String key, Object? value) {
  if (!_enabled) return;
  try {
    final v = value?.toString() ?? '';
    FirebaseCrashlytics.instance.setCustomKey(key, v);
  } catch (_) {}
}

String _safe(Object? v) {
  if (v == null) return 'null';
  final s = v.toString();
  // Guard against runaway strings blowing the log ring buffer.
  if (s.length > 120) return '${s.substring(0, 117)}...';
  return s;
}
