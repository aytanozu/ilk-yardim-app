import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/models/training_item.dart';

class CategoryGrid extends StatelessWidget {
  const CategoryGrid({super.key, this.onSelect});

  final void Function(TrainingCategory)? onSelect;

  static const _meta = <TrainingCategory, _Meta>{
    TrainingCategory.basic:
        _Meta(Icons.medical_information_rounded, AppColors.primary),
    TrainingCategory.injuries:
        _Meta(Icons.healing_rounded, AppColors.secondary),
    TrainingCategory.cardio:
        _Meta(Icons.favorite_rounded, AppColors.primary),
    TrainingCategory.poisoning:
        _Meta(Icons.science_rounded, AppColors.tertiary),
  };

  @override
  Widget build(BuildContext context) {
    final items = _meta.entries.toList();
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: AppSpacing.sm,
        crossAxisSpacing: AppSpacing.sm,
        childAspectRatio: 1.4,
      ),
      itemBuilder: (_, i) {
        final e = items[i];
        return InkWell(
          borderRadius: AppSpacing.borderXl,
          onTap: onSelect == null ? null : () => onSelect!(e.key),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: const BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: AppSpacing.borderXl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.xs),
                  decoration: BoxDecoration(
                    color: e.value.color.withOpacity(0.12),
                    borderRadius: AppSpacing.borderSm,
                  ),
                  child: Icon(e.value.icon, color: e.value.color, size: 20),
                ),
                const Spacer(),
                Text(
                  e.key.turkish,
                  style: AppTypography.titleSm.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Meta {
  const _Meta(this.icon, this.color);
  final IconData icon;
  final Color color;
}
