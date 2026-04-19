import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/models/emergency_case.dart';
import '../../../shared/widgets/primary_gradient_button.dart';

class EmergencyAlertCard extends StatelessWidget {
  const EmergencyAlertCard({
    super.key,
    required this.emergency,
    required this.distanceMeters,
    required this.etaSeconds,
    required this.onAccept,
    required this.onDetails,
  });

  final EmergencyCase emergency;
  final double? distanceMeters;
  final double? etaSeconds;
  final VoidCallback onAccept;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    final distanceLabel = distanceMeters == null
        ? '—'
        : distanceMeters! < 1000
            ? '${distanceMeters!.round()}m'
            : '${(distanceMeters! / 1000).toStringAsFixed(1)} km';
    final etaLabel = etaSeconds == null
        ? '—'
        : '${(etaSeconds! / 60).ceil()} Dk';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: const BorderRadius.vertical(top: AppSpacing.radiusXl),
        boxShadow: AppColors.ambientShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.xs),
                decoration: BoxDecoration(
                  color: _severityColor(emergency.severity).withOpacity(0.15),
                  borderRadius: AppSpacing.borderFull,
                ),
                child: Icon(
                  _severityIcon(emergency.severity),
                  color: _severityColor(emergency.severity),
                  size: 18,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'ACİL ÇAĞRI',
                style: AppTypography.labelMd.copyWith(
                  color: _severityColor(emergency.severity),
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
              const Spacer(),
              if (emergency.hazards.isNotEmpty)
                _HazardChip(hazards: emergency.hazards),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${emergency.type.turkish} Şüphesi',
            style: AppTypography.headlineSm
                .copyWith(fontWeight: FontWeight.w700, height: 1.1),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            emergency.address,
            style: AppTypography.bodyMd.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              _MetricChip(
                icon: Icons.directions_walk_rounded,
                label: 'Mesafe: $distanceLabel',
              ),
              const SizedBox(width: AppSpacing.xs),
              _MetricChip(
                icon: Icons.access_time_rounded,
                label: etaLabel,
                highlight: true,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          PrimaryGradientButton(
            label: 'Yardıma Git',
            trailingIcon: Icons.arrow_forward_rounded,
            onPressed: onAccept,
          ),
          const SizedBox(height: AppSpacing.xxs),
          Center(
            child: TextButton(
              onPressed: onDetails,
              child: Text(
                'Detayları Gör',
                style: AppTypography.labelMd
                    .copyWith(color: AppColors.secondary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _severityColor(Severity s) {
    switch (s) {
      case Severity.critical:
        return AppColors.severityCritical;
      case Severity.serious:
        return AppColors.severitySerious;
      case Severity.minor:
        return AppColors.severityMinor;
    }
  }

  IconData _severityIcon(Severity s) {
    switch (s) {
      case Severity.critical:
        return Icons.warning_amber_rounded;
      case Severity.serious:
        return Icons.priority_high_rounded;
      case Severity.minor:
        return Icons.medical_services_rounded;
    }
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.icon,
    required this.label,
    this.highlight = false,
  });

  final IconData icon;
  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: highlight
            ? AppColors.primaryFixed
            : AppColors.surfaceContainerLow,
        borderRadius: AppSpacing.borderFull,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: highlight
                ? AppColors.primary
                : AppColors.onSurfaceVariant,
          ),
          const SizedBox(width: AppSpacing.xxs),
          Text(
            label,
            style: AppTypography.labelMd.copyWith(
              color: highlight
                  ? AppColors.onPrimaryFixedVariant
                  : AppColors.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _HazardChip extends StatelessWidget {
  const _HazardChip({required this.hazards});
  final List<String> hazards;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.12),
        borderRadius: AppSpacing.borderFull,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.report_problem_rounded,
            size: 14,
            color: AppColors.error,
          ),
          const SizedBox(width: AppSpacing.xxs),
          Text(
            'Dikkat',
            style: AppTypography.labelSm.copyWith(
              color: AppColors.error,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
