import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/nav_launcher.dart';
import '../data/aed_repo.dart';

/// Compact chip that streams active AEDs in the vicinity of the incident
/// and surfaces the nearest one with a tap-to-navigate shortcut — the
/// single largest survival multiplier after early CPR.
class NearestAedChip extends StatelessWidget {
  const NearestAedChip({
    super.key,
    required this.incidentLat,
    required this.incidentLng,
  });

  final double incidentLat;
  final double incidentLng;

  @override
  Widget build(BuildContext context) {
    final repo = AedRepo();
    return StreamBuilder<List<AedEntry>>(
      stream: repo.watchNearby(lat: incidentLat, lng: incidentLng),
      builder: (context, snap) {
        final items = snap.data ?? const [];
        if (items.isEmpty) return const SizedBox.shrink();
        items.sort((a, b) {
          final da = distanceMeters(
            a.location.latitude,
            a.location.longitude,
            incidentLat,
            incidentLng,
          );
          final db = distanceMeters(
            b.location.latitude,
            b.location.longitude,
            incidentLat,
            incidentLng,
          );
          return da.compareTo(db);
        });
        final nearest = items.first;
        final meters = distanceMeters(
          nearest.location.latitude,
          nearest.location.longitude,
          incidentLat,
          incidentLng,
        ).round();
        // Hide if the "nearest" AED is absurdly far (>2 km) — in that
        // case the chip is noise, the volunteer isn't detouring.
        if (meters > 2000) return const SizedBox.shrink();

        return InkWell(
          borderRadius: AppSpacing.borderFull,
          onTap: () {
            NavLauncher.openWalking(
              lat: nearest.location.latitude,
              lng: nearest.location.longitude,
              label: nearest.name,
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm + 2,
              vertical: AppSpacing.xxs + 2,
            ),
            decoration: BoxDecoration(
              color: AppColors.tertiary,
              borderRadius: AppSpacing.borderFull,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.medical_services_rounded,
                    color: Colors.white, size: 14),
                const SizedBox(width: 6),
                Text(
                  'AED · ${_fmtMeters(meters)}',
                  style: AppTypography.labelMd.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.directions_walk_rounded,
                    color: Colors.white, size: 14),
              ],
            ),
          ),
        );
      },
    );
  }

  static String _fmtMeters(int m) {
    if (m < 1000) return '$m m';
    return '${(m / 1000).toStringAsFixed(1)} km';
  }
}
