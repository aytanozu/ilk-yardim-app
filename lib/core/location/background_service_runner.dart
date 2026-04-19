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
import 'geohash.dart';

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
    try {
      if (await _service.isRunning()) {
        debugPrint('[bgservice] already running');
        return;
      }
      final ok = await _service.startService();
      debugPrint('[bgservice] startService returned: $ok');
    } catch (e, s) {
      debugPrint('[bgservice] start failed: $e\n$s');
    }
  }

  Future<void> stop() async {
    if (!await _service.isRunning()) return;
    _service.invoke('stopService');
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

  Future<void> handle(Position pos) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final now = DateTime.now();
    if (lastWrite != null &&
        now.difference(lastWrite!) < const Duration(seconds: 30) &&
        lastWritten != null &&
        Geolocator.distanceBetween(
              lastWritten!.latitude,
              lastWritten!.longitude,
              pos.latitude,
              pos.longitude,
            ) <
            50) {
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'lastLocation': GeoPoint(pos.latitude, pos.longitude),
        'geohash': geohashEncode(pos.latitude, pos.longitude, precision: 7),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      lastWrite = now;
      lastWritten = pos;
    } catch (e) {
      debugPrint('bg service write failed: $e');
    }

    // Keep the Android foreground notification fresh
    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: 'Klinik Nabız · Aktif',
        content: 'Son güncelleme ${_fmtTime(now)}',
      );
    }
  }

  // Listen for positions at ~30s cadence with distance filter.
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

  // When service is stopped, cancel the subscription.
  service.on('stopService').listen((_) {
    sub.cancel();
  });
}

String _fmtTime(DateTime t) {
  final hh = t.hour.toString().padLeft(2, '0');
  final mm = t.minute.toString().padLeft(2, '0');
  return '$hh:$mm';
}
