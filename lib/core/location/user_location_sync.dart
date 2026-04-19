import 'dart:async';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

import 'location_provider.dart';
import 'geohash.dart';

/// Mirrors the local LocationProvider position to `users/{uid}` so Cloud
/// Functions can geo-query nearby volunteers. Writes at most every 30s
/// or after 50m of movement to limit Firestore cost.
class UserLocationSync {
  UserLocationSync({required this.provider});

  final LocationProvider provider;
  VoidCallback? _detach;
  DateTime? _lastWrite;
  Position? _lastWrittenPosition;

  void start() {
    stop();
    final listener = () => _maybeWrite();
    provider.addListener(listener);
    _detach = () => provider.removeListener(listener);
    _maybeWrite();
  }

  void stop() {
    _detach?.call();
    _detach = null;
  }

  Future<void> _maybeWrite() async {
    final pos = provider.position;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (pos == null || uid == null) return;

    final now = DateTime.now();
    if (_lastWrite != null &&
        now.difference(_lastWrite!) < const Duration(seconds: 30) &&
        _lastWrittenPosition != null &&
        Geolocator.distanceBetween(
              _lastWrittenPosition!.latitude,
              _lastWrittenPosition!.longitude,
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
      _lastWrite = now;
      _lastWrittenPosition = pos;
    } catch (_) {
      // Silent — network retry on next tick
    }
  }
}
