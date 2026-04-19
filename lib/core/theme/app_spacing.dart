import 'package:flutter/material.dart';

/// Stitch spacingScale=2 → 8px base; Material roundness ROUND_EIGHT=8 default,
/// kartlar xl (24).
class AppSpacing {
  AppSpacing._();

  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;

  // Radius scale
  static const Radius radiusXs = Radius.circular(4);
  static const Radius radiusSm = Radius.circular(8);
  static const Radius radiusMd = Radius.circular(12);
  static const Radius radiusLg = Radius.circular(16);
  static const Radius radiusXl = Radius.circular(24);
  static const Radius radiusFull = Radius.circular(999);

  static const BorderRadius borderXs = BorderRadius.all(radiusXs);
  static const BorderRadius borderSm = BorderRadius.all(radiusSm);
  static const BorderRadius borderMd = BorderRadius.all(radiusMd);
  static const BorderRadius borderLg = BorderRadius.all(radiusLg);
  static const BorderRadius borderXl = BorderRadius.all(radiusXl);
  static const BorderRadius borderFull = BorderRadius.all(radiusFull);
}
