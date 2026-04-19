import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../data/debrief_repo.dart';
import '../models/debrief_entry.dart';

class DebriefListScreen extends StatelessWidget {
  const DebriefListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final repo = DebriefRepo();
    final df = DateFormat('d MMM yyyy · HH:mm', 'tr_TR');

    return Scaffold(
      appBar: AppBar(
        title: Text('Geçmiş Müdahalelerim',
            style:
                AppTypography.titleMd.copyWith(fontWeight: FontWeight.w700)),
      ),
      body: uid == null
          ? const Center(child: Text('Giriş yapın'))
          : StreamBuilder<List<DebriefEntry>>(
              stream: repo.watchRecent(uid),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child:
                          CircularProgressIndicator(color: AppColors.primary));
                }
                final items = snap.data ?? const [];
                if (items.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Text(
                      'Henüz kayıt yok. Bir müdahale sonrası yaptığınız '
                      'yansıtmalar burada listelenir.',
                      style: AppTypography.bodyMd.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: items.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (_, i) {
                    final e = items[i];
                    return Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLowest,
                        borderRadius: AppSpacing.borderLg,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _moodChip(e.mood),
                              const Spacer(),
                              Text(
                                e.createdAt == null
                                    ? ''
                                    : df.format(e.createdAt!),
                                style: AppTypography.labelSm.copyWith(
                                  color: AppColors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                          if ((e.wentWell ?? '').isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.xs),
                            Text('İyi giden: ${e.wentWell!}',
                                style: AppTypography.bodySm),
                          ],
                          if ((e.wasHard ?? '').isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.xxs),
                            Text('Zor olan: ${e.wasHard!}',
                                style: AppTypography.bodySm),
                          ],
                          if ((e.nextTime ?? '').isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.xxs),
                            Text('Sonraki sefer: ${e.nextTime!}',
                                style: AppTypography.bodySm),
                          ],
                        ],
                      ),
                    );
                  },
                );
              },
            ),
    );
  }

  Widget _moodChip(DebriefMood m) {
    final (label, color) = switch (m) {
      DebriefMood.ok => ('İyiyim', AppColors.tertiary),
      DebriefMood.hard => ('Zorlandım', AppColors.secondary),
      DebriefMood.supportNeeded => ('Destek aldım', AppColors.primary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: AppSpacing.borderFull,
      ),
      child: Text(label,
          style: AppTypography.labelSm.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          )),
    );
  }
}
