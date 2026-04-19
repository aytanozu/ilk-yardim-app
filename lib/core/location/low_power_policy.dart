import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Three-step battery-aware location policy. Polled periodically from the
/// background isolate so volunteers with tight power budgets (end of day,
/// older devices) don't drain themselves out of availability.
///
/// Thresholds:
///   - ≥ 20 %: full  — 20 s interval, 25 m distance filter, high accuracy.
///   - < 20 %: low   — 60 s interval, 100 m distance filter, medium accuracy.
///   - < 10 %: suspended — stream stops; caller writes `available: false`
///                         to users/{uid} with reason 'low_battery'.
enum LocationPowerMode { full, low, suspended }

class LocationPolicy {
  const LocationPolicy({
    required this.mode,
    required this.throttleSeconds,
    required this.distanceFilterMeters,
    required this.accuracy,
  });

  final LocationPowerMode mode;
  final int throttleSeconds;
  final int distanceFilterMeters;
  final LocationAccuracy accuracy;

  bool get shouldTrack => mode != LocationPowerMode.suspended;

  static const full = LocationPolicy(
    mode: LocationPowerMode.full,
    throttleSeconds: 30,
    distanceFilterMeters: 25,
    accuracy: LocationAccuracy.high,
  );

  /// Active-case override: 10-second / 10-meter cadence so the operator
  /// polyline is live and arrival detection is tight. Used while
  /// users/{uid}.activeEmergencyId is set.
  static const burst = LocationPolicy(
    mode: LocationPowerMode.full,
    throttleSeconds: 10,
    distanceFilterMeters: 10,
    accuracy: LocationAccuracy.best,
  );

  static const low = LocationPolicy(
    mode: LocationPowerMode.low,
    throttleSeconds: 60,
    distanceFilterMeters: 100,
    accuracy: LocationAccuracy.medium,
  );

  static const suspended = LocationPolicy(
    mode: LocationPowerMode.suspended,
    throttleSeconds: 0,
    distanceFilterMeters: 9999,
    accuracy: LocationAccuracy.low,
  );

  static LocationPolicy forBatteryPercent(int percent) {
    if (percent < 10) return suspended;
    if (percent < 20) return low;
    return full;
  }
}

/// Safe battery read that never throws into the isolate; defaults to 100
/// on unsupported platforms so we err on "full mode" rather than silently
/// suspending tracking.
Future<int> readBatteryPercent() async {
  try {
    return await Battery().batteryLevel;
  } catch (e) {
    debugPrint('battery read failed: $e');
    return 100;
  }
}
