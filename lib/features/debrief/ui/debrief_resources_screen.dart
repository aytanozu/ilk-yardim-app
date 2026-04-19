import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/primary_gradient_button.dart';
import '../data/debrief_repo.dart';
import '../models/debrief_entry.dart';

/// Final screen of the debrief flow: Turkish mental-health resources
/// (Türk Kızılay psikososyal destek, Türkiye Psikiyatri Derneği, 112),
/// a guided 4-7-8 breathing card, and the save-to-journal action.
class DebriefResourcesScreen extends StatefulWidget {
  const DebriefResourcesScreen({
    super.key,
    required this.emergencyId,
    required this.mood,
    this.wentWell,
    this.wasHard,
    this.nextTime,
    this.selfRating,
  });

  final String emergencyId;
  final DebriefMood mood;
  final String? wentWell;
  final String? wasHard;
  final String? nextTime;
  final int? selfRating;

  @override
  State<DebriefResourcesScreen> createState() => _DebriefResourcesScreenState();
}

class _DebriefResourcesScreenState extends State<DebriefResourcesScreen> {
  final _repo = DebriefRepo();
  bool _saving = false;

  Future<void> _saveAndExit() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      if (mounted) context.go('/');
      return;
    }
    setState(() => _saving = true);
    try {
      await _repo.save(
        uid: uid,
        entry: DebriefEntry(
          emergencyId: widget.emergencyId,
          mood: widget.mood,
          wentWell: widget.wentWell,
          wasHard: widget.wasHard,
          nextTime: widget.nextTime,
          selfRating: widget.selfRating,
        ),
      );
      await _repo.clearPending();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kayıt alındı. Kendinize iyi bakın.'),
          backgroundColor: AppColors.tertiary,
        ),
      );
      context.go('/');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Kaydedilemedi: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Destek Kaynakları',
            style: AppTypography.titleMd.copyWith(fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: AppSpacing.borderLg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Yalnız değilsiniz',
                    style: AppTypography.titleMd.copyWith(
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Bir ilk yardım müdahalesinden sonra zorlanmak doğaldır. '
                  'Aşağıdaki kurumlar profesyonel destek sunar. Klinik Nabız '
                  'profesyonel psikolojik bakım yerine geçmez.',
                  style: AppTypography.bodyMd.copyWith(
                    color: AppColors.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _ResourceCard(
            title: 'Türk Kızılay · Psikososyal Destek',
            subtitle: '+90 312 584 18 68',
            url: 'https://www.kizilay.org.tr',
            phone: '+903125841868',
            icon: Icons.volunteer_activism_rounded,
          ),
          const SizedBox(height: AppSpacing.sm),
          _ResourceCard(
            title: 'Türkiye Psikiyatri Derneği',
            subtitle: '+90 312 468 74 97 · psikiyatri.org.tr',
            url: 'https://psikiyatri.org.tr/',
            phone: '+903124687497',
            icon: Icons.psychology_rounded,
          ),
          const SizedBox(height: AppSpacing.sm),
          _ResourceCard(
            title: '112 Acil Sağlık',
            subtitle: 'Acil durumlar için — 7/24',
            phone: '112',
            icon: Icons.local_hospital_rounded,
          ),
          const SizedBox(height: AppSpacing.lg),
          _BreathingCard(),
          const SizedBox(height: AppSpacing.lg),
          PrimaryGradientButton(
            label: _saving ? 'Kaydediliyor…' : 'Kaydet ve Bitir',
            icon: Icons.check_rounded,
            onPressed: _saving ? null : _saveAndExit,
          ),
        ],
      ),
    );
  }
}

class _ResourceCard extends StatelessWidget {
  const _ResourceCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.url,
    this.phone,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final String? url;
  final String? phone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: AppSpacing.borderLg,
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 24),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppTypography.titleSm.copyWith(
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: AppTypography.bodySm.copyWith(
                        color: AppColors.onSurfaceVariant)),
              ],
            ),
          ),
          if (phone != null)
            IconButton(
              icon: const Icon(Icons.phone_rounded,
                  color: AppColors.tertiary),
              onPressed: () => launchUrl(Uri.parse('tel:$phone')),
            ),
          if (url != null)
            IconButton(
              icon: const Icon(Icons.open_in_new_rounded,
                  color: AppColors.secondary),
              onPressed: () => launchUrl(
                Uri.parse(url!),
                mode: LaunchMode.externalApplication,
              ),
            ),
        ],
      ),
    );
  }
}

/// Static "4-7-8 breathing" reminder card. Concrete enough to use right
/// now without needing a timer animation — if users need a guided timer
/// we can add it later.
class _BreathingCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.tertiary.withOpacity(0.08),
        borderRadius: AppSpacing.borderLg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.air_rounded, color: AppColors.tertiary),
              const SizedBox(width: AppSpacing.xs),
              Text('4-7-8 Nefes Egzersizi',
                  style: AppTypography.titleSm.copyWith(
                      fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '1. Burundan 4 saniye nefes alın.\n'
            '2. Nefesinizi 7 saniye tutun.\n'
            '3. Ağızdan 8 saniye yavaşça verin.\n\n'
            '4 döngü tekrar edin. Parasempatik sinir sistemi aktifleşir, '
            'nabız düşer ve kas gerginliği azalır.',
            style: AppTypography.bodySm.copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }
}
