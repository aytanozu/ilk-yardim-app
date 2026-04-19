import 'dart:convert';

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

/// Remote Config wrapper — controls pilot region enablement + wave timings.
class AppRemoteConfig {
  AppRemoteConfig._();
  static final AppRemoteConfig instance = AppRemoteConfig._();

  static const _kEnabledDistricts = 'enabledDistricts';
  static const _kMaxRadiusKm = 'maxResponseRadiusKm';

  static const _defaults = <String, dynamic>{
    _kEnabledDistricts: '["istanbul_kadikoy"]',
    _kMaxRadiusKm: 10,
  };

  Future<void> init() async {
    try {
      final rc = FirebaseRemoteConfig.instance;
      await rc.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 10),
          minimumFetchInterval:
              kDebugMode ? Duration.zero : const Duration(hours: 1),
        ),
      );
      await rc.setDefaults(_defaults);
      await rc.fetchAndActivate();
    } catch (e) {
      debugPrint('RemoteConfig init failed: $e');
    }
  }

  List<String> enabledDistricts() {
    try {
      final raw = FirebaseRemoteConfig.instance.getString(_kEnabledDistricts);
      final decoded = jsonDecode(raw);
      if (decoded is List) return decoded.cast<String>();
    } catch (_) {}
    final fallback = _defaults[_kEnabledDistricts] as String;
    return (jsonDecode(fallback) as List).cast<String>();
  }

  bool isDistrictEnabled(String city, String district) {
    final key = '${city}_$district'.toLowerCase();
    return enabledDistricts().map((e) => e.toLowerCase()).contains(key);
  }

  double maxRadiusKm() {
    try {
      return FirebaseRemoteConfig.instance.getDouble(_kMaxRadiusKm);
    } catch (_) {
      return (_defaults[_kMaxRadiusKm] as num).toDouble();
    }
  }
}
