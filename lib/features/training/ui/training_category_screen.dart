import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/models/training_item.dart';
import '../data/training_repo.dart';
import '../widgets/video_card.dart';

class TrainingCategoryScreen extends StatelessWidget {
  const TrainingCategoryScreen({super.key, required this.categoryKey});
  final String categoryKey;

  @override
  Widget build(BuildContext context) {
    final category = TrainingCategory.fromKey(categoryKey);
    final repo = TrainingRepo();
    return Scaffold(
      appBar: AppBar(
        title: Text(category.turkish),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: FutureBuilder<List<TrainingItem>>(
        future: repo.byCategory(category),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snap.data ?? const [];
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Text(
                  'Bu kategoride içerik yok.',
                  style: AppTypography.bodyMd.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ),
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.all(AppSpacing.md),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 280,
              mainAxisSpacing: AppSpacing.md,
              crossAxisSpacing: AppSpacing.md,
              childAspectRatio: 0.78,
            ),
            itemCount: items.length,
            itemBuilder: (_, i) => VideoCard(
              item: items[i],
              onTap: () => context.push('/training/item/${items[i].id}'),
            ),
          );
        },
      ),
    );
  }
}
