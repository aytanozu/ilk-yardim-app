import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import '../observability/breadcrumbs.dart';

/// Opens the platform's default turn-by-turn navigation app pointing at the
/// given coordinate. Prefers Google Maps if installed (walking mode by
/// default), falls back to the generic `geo:` intent on Android / Apple
/// Maps on iOS.
class NavLauncher {
  NavLauncher._();

  static Future<bool> openWalking({
    required double lat,
    required double lng,
    String? label,
  }) async {
    breadcrumb('nav_launch', {'lat': lat, 'lng': lng, 'label': label});
    final l = label != null ? '(${Uri.encodeComponent(label)})' : '';
    if (Platform.isAndroid) {
      // Google Maps navigation intent — walking mode.
      final gmaps = Uri.parse('google.navigation:q=$lat,$lng&mode=w');
      if (await canLaunchUrl(gmaps)) {
        return launchUrl(gmaps, mode: LaunchMode.externalApplication);
      }
      // Generic geo intent — Android will offer any installed map app.
      final geo = Uri.parse('geo:$lat,$lng?q=$lat,$lng$l');
      return launchUrl(geo, mode: LaunchMode.externalApplication);
    }
    if (Platform.isIOS) {
      // Google Maps on iOS
      final gmaps =
          Uri.parse('comgooglemaps://?daddr=$lat,$lng&directionsmode=walking');
      if (await canLaunchUrl(gmaps)) {
        return launchUrl(gmaps, mode: LaunchMode.externalApplication);
      }
      // Apple Maps
      final apple = Uri.parse('http://maps.apple.com/?daddr=$lat,$lng&dirflg=w');
      return launchUrl(apple, mode: LaunchMode.externalApplication);
    }
    debugPrint('NavLauncher: unsupported platform');
    return false;
  }
}
