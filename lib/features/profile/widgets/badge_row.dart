import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

class VolunteerBadge {
  const VolunteerBadge(this.id, this.label, this.icon, this.color);
  final String id;
  final String label;
  final IconData icon;
  final Color color;

  static const catalog = <VolunteerBadge>[
    VolunteerBadge(
      'life_saver',
      'Hayat Kurtaran',
      Icons.favorite_rounded,
      AppColors.primary,
    ),
    VolunteerBadge(
      'trainer',
      'Eğitmen',
      Icons.school_rounded,
      AppColors.secondary,
    ),
    VolunteerBadge(
      'rapid_response',
      'Hızlı Müdahale',
      Icons.bolt_rounded,
      AppColors.tertiary,
    ),
    VolunteerBadge(
      'trainer_plus',
      'Uzman Eğitmen',
      Icons.auto_stories_rounded,
      AppColors.secondary,
    ),
    VolunteerBadge(
      'streak_4w',
      '4 Hafta Aktif',
      Icons.local_fire_department_rounded,
      AppColors.primary,
    ),
    VolunteerBadge(
      'aed_reporter',
      'AED Katkıcısı',
      Icons.medical_services_rounded,
      AppColors.tertiary,
    ),
  ];
}

class BadgeRow extends StatelessWidget {
  const BadgeRow({super.key, required this.earnedIds});

  final List<String> earnedIds;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: VolunteerBadge.catalog.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (_, i) {
          final badge = VolunteerBadge.catalog[i];
          final earned = earnedIds.contains(badge.id);
          return _BadgeCard(badge: badge, earned: earned);
        },
      ),
    );
  }
}

class _BadgeCard extends StatelessWidget {
  const _BadgeCard({required this.badge, required this.earned});

  final VolunteerBadge badge;
  final bool earned;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 110,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: earned
            ? AppColors.surfaceContainerLowest
            : AppColors.surfaceContainerLow,
        borderRadius: AppSpacing.borderLg,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: earned ? badge.color.withOpacity(0.12) : Colors.transparent,
              borderRadius: AppSpacing.borderFull,
            ),
            child: Icon(
              badge.icon,
              color: earned ? badge.color : AppColors.onSurfaceVariant,
              size: 22,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            badge.label,
            textAlign: TextAlign.center,
            style: AppTypography.labelSm.copyWith(
              fontWeight: FontWeight.w600,
              color: earned ? AppColors.onSurface : AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
