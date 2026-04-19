import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../models/debrief_entry.dart';

/// Step 1 of the post-incident debrief. Asks "how are you?" with three
/// large tap targets; the result is propagated to the checklist step
/// via go_router extra. "supportNeeded" deep-links straight to resources.
class DebriefCheckInScreen extends StatelessWidget {
  const DebriefCheckInScreen({
    super.key,
    required this.emergencyId,
  });

  final String emergencyId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Nasılsınız?',
            style: AppTypography.titleMd.copyWith(fontWeight: FontWeight.w700)),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.go('/'),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Az önce bir çağrıya katıldınız. Kendinizi nasıl '
              'hissediyorsunuz? Bu bilgi hiçbir yere paylaşılmaz — '
              'sadece kendi kaydınıza eklenir.',
              style: AppTypography.bodyMd.copyWith(
                color: AppColors.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            _MoodTile(
              mood: DebriefMood.ok,
              title: 'İyiyim',
              subtitle: 'Her şey yolunda, devam edebilirim.',
              icon: Icons.sentiment_satisfied_rounded,
              color: AppColors.tertiary,
              onTap: () => _next(context, DebriefMood.ok),
            ),
            const SizedBox(height: AppSpacing.md),
            _MoodTile(
              mood: DebriefMood.hard,
              title: 'Biraz zorlandım',
              subtitle: 'Etkilendim, notlarımı almak istiyorum.',
              icon: Icons.sentiment_neutral_rounded,
              color: AppColors.secondary,
              onTap: () => _next(context, DebriefMood.hard),
            ),
            const SizedBox(height: AppSpacing.md),
            _MoodTile(
              mood: DebriefMood.supportNeeded,
              title: 'Destek almak istiyorum',
              subtitle: 'Kaynaklara doğrudan yönlendir.',
              icon: Icons.favorite_rounded,
              color: AppColors.primary,
              onTap: () => _next(context, DebriefMood.supportNeeded),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => context.go('/'),
              child: const Text('Şimdi değil'),
            ),
          ],
        ),
      ),
    );
  }

  void _next(BuildContext context, DebriefMood mood) {
    // Support-needed users jump straight to the resources screen.
    if (mood == DebriefMood.supportNeeded) {
      context.push('/debrief/$emergencyId/resources',
          extra: {'mood': mood, 'skipChecklist': true});
    } else {
      context.push('/debrief/$emergencyId/checklist', extra: {'mood': mood});
    }
  }
}

class _MoodTile extends StatelessWidget {
  const _MoodTile({
    required this.mood,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final DebriefMood mood;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: AppSpacing.borderLg,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: AppSpacing.borderLg,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: AppSpacing.borderFull,
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: AppTypography.titleMd.copyWith(
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(subtitle,
                      style: AppTypography.bodySm.copyWith(
                          color: AppColors.onSurfaceVariant)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
