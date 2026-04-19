import 'dart:async';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:geolocator/geolocator.dart';

import '../../firebase_options.dart';
import '../firebase/emulator_config.dart';
import '../observability/breadcrumbs.dart';
import 'geohash.dart';
import 'low_power_policy.dart';

/// Runs a separate Dart isolate as an Android foreground service so the
/// volunteer's location continues to sync even after the app is swiped off
/// the recent-apps list or killed by the OS. The service persists via
/// `startForegroundService` + a permanent notification.
///
/// This isolate re-initializes Firebase independently; it relies on the
/// persisted auth session token to write as the signed-in user.
class BackgroundServiceRunner {
  BackgroundServiceRunner._();
  static final BackgroundServiceRunner instance = BackgroundServiceRunner._();

  final _service = FlutterBackgroundService();

  Future<void> configure() async {
    if (kUseFirebaseEmulator) {
      debugPrint('[bgservice] configure skipped (emulator build)');
      return;
    }
    await _service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: _onStart,
        autoStart: false, // we start explicitly once user is authenticated
        isForegroundMode: true,
        foregroundServiceTypes: [AndroidForegroundType.location],
        notificationChannelId: 'volunteer_active',
        initialNotificationTitle: 'Klinik Nabız · Aktif',
        initialNotificationContent: 'Yakındaki acil çağrılar için bekleniyor',
        foregroundServiceNotificationId: 9900,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: _onStart,
        onBackground: _iosBackgroundHandler,
      ),
    );
  }

  Future<bool> get isRunning => _service.isRunning();

  Future<void> start() async {
    // Skip on emulator builds: the foreground service competes with the
    // in-app Geolocator subscription and frequently crashes with
    // CannotPostForegroundServiceNotificationException on Android 14+
    // emulators. Production release builds still get the real service.
    if (kUseFirebaseEmulator) {
      debugPrint('[bgservice] skipped (emulator build)');
      breadcrumb('bg_start_skipped_emulator');
      return;
    }
    try {
      if (await _service.isRunning()) {
        debugPrint('[bgservice] already running');
        breadcrumb('bg_start_noop');
        return;
      }
      final ok = await _service.startService();
      debugPrint('[bgservice] startService returned: $ok');
      breadcrumb('bg_start', {'ok': ok});
    } catch (e, s) {
      debugPrint('[bgservice] start failed: $e\n$s');
      breadcrumb('bg_start_fail', {'err': e.toString()});
    }
  }

  Future<void> stop() async {
    if (!await _service.isRunning()) return;
    _service.invoke('stopService');
    breadcrumb('bg_stop');
  }
}

@pragma('vm:entry-point')
Future<bool> _iosBackgroundHandler(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  return true;
}

@pragma('vm:entry-point')
Future<void> _onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  // Firebase is its own isolate state; initialize in this isolate too.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {
    // Already initialized.
  }

  service.on('stopService').listen((_) {
    service.stopSelf();
  });

  debugPrint('[bgservice] onStart fired');

  // Set up the foreground notification content FIRST, then transition
  // the service to foreground. Android 14/15 reject an empty/default
  // notification at startForeground time.
  if (service is AndroidServiceInstance) {
    try {
      service.setForegroundNotificationInfo(
        title: 'Klinik Nabız · Aktif',
        content: 'Yakındaki acil çağrılar için bekleniyor',
      );
      await service.setAsForegroundService();
    } catch (e) {
      debugPrint('setAsForegroundService failed: $e');
    }
  }

  DateTime? lastWrite;
  Position? lastWritten;
  LocationPolicy batteryPolicy = LocationPolicy.full;
  LocationPolicy currentPolicy = LocationPolicy.full;
  bool burstActive = false;

  void recomputeEffectivePolicy() {
    // Burst mode overrides battery policy only if battery policy isn't
    // suspended (we never keep writing if battery is critically low).
    if (burstActive && batteryPolicy.mode != LocationPowerMode.suspended) {
      currentPolicy = LocationPolicy.burst;
    } else {
      currentPolicy = batteryPolicy;
    }
  }

  Future<void> applyBatteryPolicy() async {
    final pct = await readBatteryPercent();
    final next = LocationPolicy.forBatteryPercent(pct);
    if (next.mode == batteryPolicy.mode) return;
    debugPrint('[bgservice] battery policy ${batteryPolicy.mode} → '
        '${next.mode} (battery=$pct%)');
    batteryPolicy = next;
    recomputeEffectivePolicy();

    if (service is AndroidServiceInstance) {
      final modeLabel = switch (next.mode) {
        LocationPowerMode.full => 'Tam mod',
        LocationPowerMode.low => 'Düşük güç modu',
        LocationPowerMode.suspended => 'Askıya alındı',
      };
      service.setForegroundNotificationInfo(
        title: 'Klinik Nabız · $modeLabel',
        content: 'Pil: %$pct',
      );
    }

    // On suspension, flag the user as unavailable so dispatch skips
    // them. We intentionally don't auto-re-enable when battery recovers
    // — the user must flip the Settings toggle themselves.
    if (next.mode == LocationPowerMode.suspended) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .set(
            {
              'available': false,
              'autoSuspendedBy': 'low_battery',
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
        } catch (e) {
          debugPrint('auto-suspend write failed: $e');
        }
      }
    }
  }

  Future<void> handle(Position pos) async {
    if (!currentPolicy.shouldTrack) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final now = DateTime.now();
    final throttle = Duration(seconds: currentPolicy.throttleSeconds);
    final distanceGate = currentPolicy.distanceFilterMeters;
    if (lastWrite != null &&
        now.difference(lastWrite!) < throttle &&
        lastWritten != null &&
        Geolocator.distanceBetween(
              lastWritten!.latitude,
              lastWritten!.longitude,
              pos.latitude,
              pos.longitude,
            ) <
            distanceGate) {
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'lastLocation': GeoPoint(pos.latitude, pos.longitude),
        'geohash': geohashEncode(pos.latitude, pos.longitude, precision: 7),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      // During burst mode, also publish to volunteer_locations so the
      // operator dashboard can draw a live polyline without polluting
      // the indexed users collection.
      if (burstActive) {
        await FirebaseFirestore.instance
            .collection('volunteer_locations')
            .doc(uid)
            .set(
          {
            'uid': uid,
            'lat': pos.latitude,
            'lng': pos.longitude,
            'heading': pos.heading,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }
      lastWrite = now;
      lastWritten = pos;
    } catch (e) {
      debugPrint('bg service write failed: $e');
    }

    // Keep the Android foreground notification fresh.
    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: 'Klinik Nabız · Aktif',
        content: 'Son güncelleme ${_fmtTime(now)}',
      );
    }
  }

  // Seed the initial policy once Firebase init is guaranteed.
  await applyBatteryPolicy();

  // Re-check battery every 60 seconds; cheap.
  final batteryTimer =
      Timer.periodic(const Duration(seconds: 60), (_) => applyBatteryPolicy());

  // Watch users/{uid}.activeEmergencyId. When it goes non-null the
  // volunteer just accepted a case — kick into GPS burst mode. When it
  // clears (case closed / expired) revert to battery policy.
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? activeSub;
  void wireActiveCaseListener(String uid) {
    activeSub?.cancel();
    activeSub = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen((snap) {
      final active =
          (snap.data()?['activeEmergencyId'] as String?)?.isNotEmpty ?? false;
      if (active == burstActive) return;
      debugPrint('[bgservice] burst mode → $active');
      burstActive = active;
      recomputeEffectivePolicy();
    });
  }

  final bootUid = FirebaseAuth.instance.currentUser?.uid;
  if (bootUid != null) wireActiveCaseListener(bootUid);
  final authSub = FirebaseAuth.instance.authStateChanges().listen((u) {
    if (u?.uid != null) {
      wireActiveCaseListener(u!.uid);
    } else {
      activeSub?.cancel();
      burstActive = false;
      recomputeEffectivePolicy();
    }
  });

  // Listen for positions. Accuracy stays high at the OS level; Firestore
  // write cadence is throttled via currentPolicy.
  final sub = Geolocator.getPositionStream(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 25,
    ),
  ).listen(handle, onError: (e) {
    debugPrint('bg service position stream error: $e');
  });

  service.on('ping').listen((_) {
    service.invoke('pong');
  });

  // When service is stopped, cancel the subscription + timers.
  service.on('stopService').listen((_) {
    sub.cancel();
    batteryTimer.cancel();
    activeSub?.cancel();
    authSub.cancel();
  });
}

String _fmtTime(DateTime t) {
  final hh = t.hour.toString().padLeft(2, '0');
  final mm = t.minute.toString().padLeft(2, '0');
  return '$hh:$mm';
}
