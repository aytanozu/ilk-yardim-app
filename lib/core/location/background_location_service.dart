import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import 'geohash.dart';

/// Persistent background location tracker. Uses geolocator's built-in
/// Android foreground service (keeps streaming while phone is locked / app
/// is backgrounded) and throttles Firestore writes.
///
/// Start this once the user is authenticated and stop on sign-out.
class BackgroundLocationService {
  BackgroundLocationService._();
  static final BackgroundLocationService instance =
      BackgroundLocationService._();

  StreamSubscription<Position>? _sub;
  DateTime? _lastWriteAt;
  Position? _lastWrittenPos;
  bool _running = false;

  bool get isRunning => _running;

  Future<void> start() async {
    if (_running) return;

    final serviceOn = await Geolocator.isLocationServiceEnabled();
    if (!serviceOn) {
      debugPrint('Location service disabled — not starting background sync');
      return;
    }

    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      debugPrint('Location permission not granted');
      return;
    }
    // Try to upgrade to Always (required for background tracking on iOS)
    if (perm == LocationPermission.whileInUse) {
      perm = await Geolocator.requestPermission();
    }

    final settings = _platformSettings();
    _sub = Geolocator.getPositionStream(locationSettings: settings)
        .listen(_onPosition, onError: (e) {
      debugPrint('Position stream error: $e');
    });
    _running = true;
    debugPrint('BackgroundLocationService started');
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    _running = false;
    debugPrint('BackgroundLocationService stopped');
  }

  LocationSettings _platformSettings() {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 25,
        intervalDuration: const Duration(seconds: 20),
        forceLocationManager: false,
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Klinik Nabız · Aktif',
          notificationText:
              'Gönüllü olarak yakındaki acil çağrılar için bekliyorsun.',
          enableWakeLock: true,
          notificationChannelName: 'Gönüllü Aktiflik',
          setOngoing: true,
        ),
      );
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 25,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
        activityType: ActivityType.otherNavigation,
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 25,
    );
  }

  Future<void> _onPosition(Position pos) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final now = DateTime.now();
    if (_lastWriteAt != null &&
        now.difference(_lastWriteAt!) < const Duration(seconds: 30) &&
        _lastWrittenPos != null &&
        Geolocator.distanceBetween(
              _lastWrittenPos!.latitude,
              _lastWrittenPos!.longitude,
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
      _lastWriteAt = now;
      _lastWrittenPos = pos;
    } catch (e) {
      debugPrint('bg location write failed: $e');
    }
  }
}
