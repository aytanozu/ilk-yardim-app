import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Wraps geolocator with sane defaults for a first-aid volunteer context:
/// Always permission is preferred, high accuracy, foreground service on Android.
class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();

  LocationPermission? _lastStatus;

  Future<LocationPermission> currentPermission() async {
    _lastStatus = await Geolocator.checkPermission();
    return _lastStatus!;
  }

  Future<bool> isServiceEnabled() => Geolocator.isLocationServiceEnabled();

  /// Request permissions in sequence: whenInUse → always.
  /// Returns true if the final state is granted (whileInUse or always).
  Future<bool> requestPermission({bool requestAlways = true}) async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return false;
    }

    var status = await Geolocator.checkPermission();
    if (status == LocationPermission.denied) {
      status = await Geolocator.requestPermission();
    }
    if (status == LocationPermission.deniedForever) {
      return false;
    }

    if (requestAlways && status == LocationPermission.whileInUse) {
      final elevated = await Geolocator.requestPermission();
      status = elevated;
    }

    _lastStatus = status;
    return status == LocationPermission.always ||
        status == LocationPermission.whileInUse;
  }

  Future<Position?> lastKnown() async {
    try {
      return await Geolocator.getLastKnownPosition();
    } catch (e) {
      debugPrint('lastKnown error: $e');
      return null;
    }
  }

  Future<Position?> currentPosition({
    LocationAccuracy accuracy = LocationAccuracy.high,
  }) async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(accuracy: accuracy),
      );
    } catch (e) {
      debugPrint('currentPosition error: $e');
      return null;
    }
  }

  Stream<Position> positionStream({
    LocationAccuracy accuracy = LocationAccuracy.high,
    int distanceFilterMeters = 10,
  }) {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilterMeters,
      ),
    );
  }

  double distanceMeters(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) =>
      Geolocator.distanceBetween(lat1, lng1, lat2, lng2);
}
