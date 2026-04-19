import 'package:flutter/material.dart';

/// Clinical Pulse design system — Stitch token'larından birebir.
/// Değerler projects/12023846913793716446/designTheme.namedColors ile senkron.
class AppColors {
  AppColors._();

  // Brand
  static const Color primary = Color(0xFFB7102A);
  static const Color primaryContainer = Color(0xFFDB313F);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onPrimaryContainer = Color(0xFFFFFBFF);
  static const Color primaryFixed = Color(0xFFFFDAD8);
  static const Color primaryFixedDim = Color(0xFFFFB3B1);
  static const Color onPrimaryFixed = Color(0xFF410007);
  static const Color onPrimaryFixedVariant = Color(0xFF92001C);

  // Secondary (navy)
  static const Color secondary = Color(0xFF485F84);
  static const Color secondaryContainer = Color(0xFFBBD3FD);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color onSecondaryContainer = Color(0xFF445A7F);
  static const Color secondaryFixed = Color(0xFFD5E3FF);
  static const Color secondaryFixedDim = Color(0xFFB0C7F1);
  static const Color onSecondaryFixed = Color(0xFF001B3C);
  static const Color onSecondaryFixedVariant = Color(0xFF30476A);

  // Tertiary (teal — stabilized / secure states)
  static const Color tertiary = Color(0xFF006860);
  static const Color tertiaryContainer = Color(0xFF008379);
  static const Color onTertiary = Color(0xFFFFFFFF);
  static const Color onTertiaryContainer = Color(0xFFF3FFFC);
  static const Color tertiaryFixed = Color(0xFF8CF4E8);
  static const Color tertiaryFixedDim = Color(0xFF6FD8CC);
  static const Color onTertiaryFixed = Color(0xFF00201D);
  static const Color onTertiaryFixedVariant = Color(0xFF00504A);

  // Error
  static const Color error = Color(0xFFBA1A1A);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color onErrorContainer = Color(0xFF93000A);

  // Surface hierarchy — tonal layering (no borders allowed)
  static const Color surface = Color(0xFFF3FCF0);
  static const Color surfaceBright = Color(0xFFF3FCF0);
  static const Color surfaceDim = Color(0xFFD4DDD1);
  static const Color surfaceContainer = Color(0xFFE7F0E5);
  static const Color surfaceContainerLow = Color(0xFFEDF6EA);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerHigh = Color(0xFFE2EBDF);
  static const Color surfaceContainerHighest = Color(0xFFDCE5D9);
  static const Color surfaceVariant = Color(0xFFDCE5D9);
  static const Color surfaceTint = Color(0xFFBB152C);

  static const Color onSurface = Color(0xFF161D16);
  static const Color onSurfaceVariant = Color(0xFF5B403F);

  // Outline (mostly forbidden — only as Ghost Border at 15% opacity)
  static const Color outline = Color(0xFF8F6F6E);
  static const Color outlineVariant = Color(0xFFE4BEBC);

  // Background
  static const Color background = Color(0xFFF3FCF0);
  static const Color onBackground = Color(0xFF161D16);

  // Inverse
  static const Color inverseSurface = Color(0xFF2A322B);
  static const Color inverseOnSurface = Color(0xFFEAF3E7);
  static const Color inversePrimary = Color(0xFFFFB3B1);

  // Severity (emergency call colors — not from Stitch, app-specific)
  static const Color severityCritical = primary;
  static const Color severitySerious = Color(0xFFE8A33C);
  static const Color severityMinor = tertiary;

  // Signature gradient (primary action buttons — 135° linear)
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryContainer],
  );

  // Ghost border color (15% outline_variant)
  static Color get ghostBorder => outlineVariant.withOpacity(0.15);

  // Ambient shadow for rare critical elevation
  static List<BoxShadow> get ambientShadow => [
        BoxShadow(
          color: onSurface.withOpacity(0.06),
          blurRadius: 24,
          spreadRadius: -2,
          offset: const Offset(0, 4),
        ),
      ];
}
