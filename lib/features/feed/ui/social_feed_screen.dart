import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/primary_gradient_button.dart';
import '../providers/feed_provider.dart';
import '../widgets/post_card.dart';

class SocialFeedScreen extends StatelessWidget {
  const SocialFeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => FeedProvider(),
      child: const _FeedBody(),
    );
  }
}

class _FeedBody extends StatelessWidget {
  const _FeedBody();

  @override
  Widget build(BuildContext context) {
    final posts = context.select<FeedProvider, List<dynamic>>((p) => p.posts);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'KLİNİK NABIZ',
          style: AppTypography.titleLg.copyWith(letterSpacing: 3),
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.notifications_none_rounded),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(child: _FeedHeader()),
          if (posts.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyState(),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                96,
              ),
              sliver: SliverList.separated(
                itemCount: posts.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpacing.md),
                itemBuilder: (ctx, i) => Selector<FeedProvider, bool>(
                  selector: (_, p) => p.isLiked(posts[i].id as String),
                  builder: (ctx, liked, __) => PostCard(
                    post: posts[i],
                    liked: liked,
                    onLikeTap: () =>
                        ctx.read<FeedProvider>().toggleLike(posts[i].id),
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: PrimaryGradientButton(
          label: 'Hikayeni Paylaş',
          icon: Icons.edit_rounded,
          expanded: false,
          onPressed: () {},
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

class _FeedHeader extends StatelessWidget {
  const _FeedHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Kurtarma Hikayeleri',
            style: AppTypography.headlineSm.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            'Topluluğumuzdan ilham veren anlar ve ilk yardım deneyimleri',
            style: AppTypography.bodyMd.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.forum_rounded,
                size: 60, color: AppColors.onSurfaceVariant.withOpacity(0.4)),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Henüz hikaye paylaşılmamış',
              style: AppTypography.titleMd.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              'İlk hikayeyi sen paylaş',
              textAlign: TextAlign.center,
              style: AppTypography.bodySm.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
