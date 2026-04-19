import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/models/training_item.dart';
import '../../../shared/widgets/primary_gradient_button.dart';

class TrainingDetailScreen extends StatelessWidget {
  const TrainingDetailScreen({super.key, required this.itemId});
  final String itemId;

  Future<TrainingItem?> _load() async {
    final doc = await FirebaseFirestore.instance
        .collection('training_items')
        .doc(itemId)
        .get();
    if (!doc.exists) return null;
    // Increment view count fire-and-forget
    doc.reference.update({'viewCount': FieldValue.increment(1)});
    return TrainingItem.fromSnapshot(doc);
  }

  Future<void> _openVideo(String? url) async {
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: FutureBuilder<TrainingItem?>(
        future: _load(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final item = snap.data;
          if (item == null) {
            return const Center(child: Text('İçerik bulunamadı'));
          }
          return SafeArea(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: item.thumbnailUrl == null
                        ? Container(color: AppColors.primaryFixed)
                        : CachedNetworkImage(
                            imageUrl: item.thumbnailUrl!,
                            fit: BoxFit.cover,
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xs,
                            vertical: AppSpacing.xxs,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryFixed,
                            borderRadius: AppSpacing.borderFull,
                          ),
                          child: Text(
                            item.category.turkish.toUpperCase(),
                            style: AppTypography.labelSm.copyWith(
                              color: AppColors.onPrimaryFixedVariant,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          item.title,
                          style: AppTypography.headlineSm.copyWith(
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          children: [
                            Icon(Icons.visibility_outlined,
                                size: 16,
                                color: AppColors.onSurfaceVariant),
                            const SizedBox(width: 4),
                            Text('${item.viewCountDisplay} izlenme',
                                style: AppTypography.labelMd.copyWith(
                                  color: AppColors.onSurfaceVariant,
                                )),
                            if (item.duration != null) ...[
                              const SizedBox(width: AppSpacing.md),
                              Icon(Icons.timer_outlined,
                                  size: 16,
                                  color: AppColors.onSurfaceVariant),
                              const SizedBox(width: 4),
                              Text(item.durationDisplay,
                                  style: AppTypography.labelMd.copyWith(
                                    color: AppColors.onSurfaceVariant,
                                  )),
                            ],
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          item.description,
                          style: AppTypography.bodyLg.copyWith(height: 1.6),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        if (item.videoUrl != null && item.videoUrl!.isNotEmpty)
                          PrimaryGradientButton(
                            label: 'Videoyu İzle',
                            icon: Icons.play_arrow_rounded,
                            onPressed: () => _openVideo(item.videoUrl),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainerLow,
                              borderRadius: AppSpacing.borderLg,
                            ),
                            child: Text(
                              'Video yakında eklenecek.',
                              style: AppTypography.bodyMd.copyWith(
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
