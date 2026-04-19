import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/models/training_item.dart';
import '../../../shared/widgets/section_header.dart';
import '../data/training_repo.dart';
import '../widgets/category_grid.dart';
import '../widgets/daily_card.dart';
import '../widgets/video_card.dart';

class TrainingCenterScreen extends StatefulWidget {
  const TrainingCenterScreen({super.key});

  @override
  State<TrainingCenterScreen> createState() => _TrainingCenterScreenState();
}

class _TrainingCenterScreenState extends State<TrainingCenterScreen> {
  final _repo = TrainingRepo();
  late Future<TrainingItem?> _featured;

  @override
  void initState() {
    super.initState();
    _featured = _repo.featured();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Eğitim Merkezi',
          style: AppTypography.titleLg.copyWith(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.search_rounded),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.xs,
              AppSpacing.md,
              AppSpacing.xxl,
            ),
            sliver: SliverList.list(
              children: [
                FutureBuilder<TrainingItem?>(
                  future: _featured,
                  builder: (_, snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return _placeholderBanner();
                    }
                    if (snap.data == null) return _placeholderBanner();
                    final item = snap.data!;
                    return DailyCard(
                      item: item,
                      onTap: () => context.push('/training/item/${item.id}'),
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Kategoriler',
                  style: AppTypography.titleLg
                      .copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AppSpacing.sm),
                CategoryGrid(
                  onSelect: (cat) =>
                      context.push('/training/category/${cat.key}'),
                ),
                const SizedBox(height: AppSpacing.lg),
                SectionHeader(
                  title: 'Popüler Videolar',
                  actionLabel: 'Tümünü Gör',
                  onAction: () {},
                ),
                SizedBox(
                  height: 220,
                  child: StreamBuilder<List<TrainingItem>>(
                    stream: _repo.watchPopular(),
                    builder: (_, snap) {
                      final items = snap.data ?? [];
                      if (items.isEmpty) return _placeholderList();
                      return ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: items.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(width: AppSpacing.sm),
                        itemBuilder: (ctx, i) => VideoCard(
                          item: items[i],
                          onTap: () => ctx
                              .push('/training/item/${items[i].id}'),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholderBanner() => Container(
        height: 240,
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: AppSpacing.borderXl,
        ),
      );

  Widget _placeholderList() => Row(
        children: List.generate(
          3,
          (_) => Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: Container(
              width: 220,
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: AppSpacing.borderLg,
              ),
            ),
          ),
        ),
      );
}
