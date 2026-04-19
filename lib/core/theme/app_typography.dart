import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Inter (Latin-Extended) — Türkçe için özel olarak seçildi (ğ, ş, ç, İ, ü).
/// Editorial-Urgency hiyerarşisi: Display (urgency) → Headline (authority)
/// → Body (information) → Label (metadata).
class AppTypography {
  AppTypography._();

  static TextStyle get _base =>
      GoogleFonts.inter(color: AppColors.onSurface);

  // Display — urgency (ETA, critical alerts)
  static TextStyle get displayLg => _base.copyWith(
        fontSize: 57,
        height: 1.12,
        letterSpacing: -0.25,
        fontWeight: FontWeight.w700,
      );

  static TextStyle get displayMd => _base.copyWith(
        fontSize: 45,
        height: 1.15,
        letterSpacing: 0,
        fontWeight: FontWeight.w700,
      );

  static TextStyle get displaySm => _base.copyWith(
        fontSize: 36,
        height: 1.22,
        fontWeight: FontWeight.w700,
      );

  // Headline — authority (section headers)
  static TextStyle get headlineLg => _base.copyWith(
        fontSize: 32,
        height: 1.25,
        letterSpacing: -0.02 * 32,
        fontWeight: FontWeight.w700,
      );

  static TextStyle get headlineMd => _base.copyWith(
        fontSize: 28,
        height: 1.28,
        letterSpacing: -0.02 * 28,
        fontWeight: FontWeight.w700,
      );

  static TextStyle get headlineSm => _base.copyWith(
        fontSize: 24,
        height: 1.33,
        letterSpacing: -0.02 * 24,
        fontWeight: FontWeight.w600,
      );

  // Title — smaller headers, card titles
  static TextStyle get titleLg => _base.copyWith(
        fontSize: 22,
        height: 1.27,
        fontWeight: FontWeight.w600,
      );

  static TextStyle get titleMd => _base.copyWith(
        fontSize: 16,
        height: 1.5,
        letterSpacing: 0.15,
        fontWeight: FontWeight.w600,
      );

  static TextStyle get titleSm => _base.copyWith(
        fontSize: 14,
        height: 1.43,
        letterSpacing: 0.1,
        fontWeight: FontWeight.w600,
      );

  // Body — information layer (Turkish line-height 1.6)
  static TextStyle get bodyLg => _base.copyWith(
        fontSize: 16,
        height: 1.6,
        letterSpacing: 0.5,
        fontWeight: FontWeight.w400,
      );

  static TextStyle get bodyMd => _base.copyWith(
        fontSize: 14,
        height: 1.6,
        letterSpacing: 0.25,
        fontWeight: FontWeight.w400,
      );

  static TextStyle get bodySm => _base.copyWith(
        fontSize: 12,
        height: 1.6,
        letterSpacing: 0.4,
        fontWeight: FontWeight.w400,
      );

  // Label — metadata (navigation uppercase)
  static TextStyle get labelLg => _base.copyWith(
        fontSize: 14,
        height: 1.43,
        letterSpacing: 0.1,
        fontWeight: FontWeight.w500,
      );

  static TextStyle get labelMd => _base.copyWith(
        fontSize: 12,
        height: 1.33,
        letterSpacing: 0.5,
        fontWeight: FontWeight.w500,
      );

  static TextStyle get labelSm => _base.copyWith(
        fontSize: 11,
        height: 1.45,
        letterSpacing: 0.5,
        fontWeight: FontWeight.w500,
      );

  static TextTheme get textTheme => TextTheme(
        displayLarge: displayLg,
        displayMedium: displayMd,
        displaySmall: displaySm,
        headlineLarge: headlineLg,
        headlineMedium: headlineMd,
        headlineSmall: headlineSm,
        titleLarge: titleLg,
        titleMedium: titleMd,
        titleSmall: titleSm,
        bodyLarge: bodyLg,
        bodyMedium: bodyMd,
        bodySmall: bodySm,
        labelLarge: labelLg,
        labelMedium: labelMd,
        labelSmall: labelSm,
      );
}
