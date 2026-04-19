import 'package:flutter/foundation.dart';
import 'package:open_location_code/open_location_code.dart';

/// Plus Codes (Open Location Code) helpers. Fully offline — no API key,
/// no network. Used as the default precise-location format for rural /
/// address-less emergencies in Turkey (vineyards, forests, construction
/// sites where a street address doesn't resolve).
///
/// Thin wrapper over the `open_location_code` package so the rest of the
/// app never imports it directly — if we ever need to swap the package
/// for an inline implementation, only this file changes.
class PlusCodeUtil {
  PlusCodeUtil._();

  /// Encode a lat/lng to a Plus Code string. Default precision 10 maps
  /// to a ~13.9 m square — sharp enough to drop a responder within sight
  /// of the scene. Use 11 for ~3 m if you need sub-building precision.
  static String encode(
    double lat,
    double lng, {
    int codeLength = 10,
  }) {
    try {
      return PlusCode.encode(
        LatLng(lat, lng),
        codeLength: codeLength,
      ).toString();
    } catch (e) {
      debugPrint('PlusCode encode failed: $e');
      return '';
    }
  }

  /// Decode a full Plus Code to a lat/lng (center of the code area).
  /// Short codes (missing the area prefix) require a [reference] point
  /// within ~25 km of the intended location to recover the full code.
  static LatLng? decode(String code, {LatLng? reference}) {
    try {
      final normalized = code.trim();
      if (normalized.isEmpty) return null;

      var pc = PlusCode(normalized);
      if (!pc.isValid) return null;

      if (!pc.isFull()) {
        if (reference == null) return null;
        pc = pc.recoverNearest(reference);
      }
      final area = pc.decode();
      return LatLng(area.center.latitude, area.center.longitude);
    } catch (e) {
      debugPrint('PlusCode decode failed: $e');
      return null;
    }
  }

  /// Shareable URL form — opens directly in any Plus Code-aware maps app
  /// (Google Maps treats https://plus.codes/<code> as a deep link).
  static String shareUrl(String code) => 'https://plus.codes/$code';
}
