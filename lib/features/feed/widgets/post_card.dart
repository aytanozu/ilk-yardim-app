import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/models/post.dart';

class PostCard extends StatelessWidget {
  const PostCard({
    super.key,
    required this.post,
    required this.liked,
    required this.onLikeTap,
    this.onCommentTap,
    this.onShareTap,
  });

  final Post post;
  final bool liked;
  final VoidCallback onLikeTap;
  final VoidCallback? onCommentTap;
  final VoidCallback? onShareTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: AppSpacing.borderXl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PostHeader(post: post),
          const SizedBox(height: AppSpacing.sm),
          Text(
            post.text,
            style: AppTypography.bodyLg,
          ),
          if (post.imageUrl != null) ...[
            const SizedBox(height: AppSpacing.sm),
            ClipRRect(
              borderRadius: AppSpacing.borderLg,
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: CachedNetworkImage(
                  imageUrl: post.imageUrl!,
                  fit: BoxFit.cover,
                  placeholder: (_, __) =>
                      Container(color: AppColors.surfaceContainer),
                  errorWidget: (_, __, ___) =>
                      Container(color: AppColors.primaryFixed),
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              _ReactionButton(
                icon: liked
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                label: '${post.likeCount} Takdir Et',
                color: liked ? AppColors.primary : AppColors.onSurfaceVariant,
                onTap: onLikeTap,
              ),
              const SizedBox(width: AppSpacing.md),
              _ReactionButton(
                icon: Icons.chat_bubble_outline_rounded,
                label: '${post.commentCount} Yorum Yap',
                onTap: onCommentTap,
              ),
              const Spacer(),
              _ReactionButton(
                icon: Icons.ios_share_rounded,
                onTap: onShareTap,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PostHeader extends StatelessWidget {
  const _PostHeader({required this.post});
  final Post post;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: AppColors.primaryFixed,
          foregroundImage: post.authorAvatarUrl != null
              ? NetworkImage(post.authorAvatarUrl!)
              : null,
          child: Text(
            _initials(post.authorName),
            style: AppTypography.labelMd.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                post.authorName,
                style:
                    AppTypography.titleSm.copyWith(fontWeight: FontWeight.w700),
              ),
              Row(
                children: [
                  Text(
                    _timeAgo(post.createdAt),
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  if (post.location != null) ...[
                    const SizedBox(width: AppSpacing.xxs),
                    const Text('·'),
                    const SizedBox(width: AppSpacing.xxs),
                    Icon(
                      Icons.location_on_rounded,
                      size: 12,
                      color: AppColors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      post.location!,
                      style: AppTypography.labelSm.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () {},
          icon: const Icon(Icons.more_vert_rounded),
          color: AppColors.onSurfaceVariant,
        ),
      ],
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  String _timeAgo(DateTime when) {
    final d = DateTime.now().difference(when);
    if (d.inMinutes < 1) return 'az önce';
    if (d.inHours < 1) return '${d.inMinutes} dk önce';
    if (d.inDays < 1) return '${d.inHours} saat önce';
    if (d.inDays < 7) return '${d.inDays} gün önce';
    return DateFormat('d MMM', 'tr_TR').format(when);
  }
}

class _ReactionButton extends StatelessWidget {
  const _ReactionButton({
    required this.icon,
    this.label,
    this.onTap,
    this.color,
  });

  final IconData icon;
  final String? label;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.onSurfaceVariant;
    return InkWell(
      onTap: onTap,
      borderRadius: AppSpacing.borderFull,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: c),
            if (label != null) ...[
              const SizedBox(width: AppSpacing.xxs),
              Text(
                label!,
                style: AppTypography.labelMd.copyWith(
                  color: c,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
