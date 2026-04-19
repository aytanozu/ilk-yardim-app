import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/primary_gradient_button.dart';

/// Shown on first launch. Blocks the app until all three required consents
/// are granted (KVKK md. 6/2 özel nitelikli sağlık verisi + hassas konum
/// + yurt dışı aktarım). Non-consent = cannot proceed.
class ConsentScreen extends StatefulWidget {
  const ConsentScreen({super.key, required this.onAccepted});

  final VoidCallback onAccepted;

  static const _kConsentKey = 'consent_v1';

  static Future<bool> alreadyAccepted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kConsentKey) ?? false;
  }

  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  bool _sensitiveHealth = false;
  bool _locationAlways = false;
  bool _crossBorder = false;

  bool get _canProceed =>
      _sensitiveHealth && _locationAlways && _crossBorder;

  Future<void> _accept() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(ConsentScreen._kConsentKey, true);
    await prefs.setString(
      'consent_v1_accepted_at',
      DateTime.now().toIso8601String(),
    );
    widget.onAccepted();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Aydınlatma ve Açık Rıza',
                style: AppTypography.headlineSm.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Klinik Nabız sağlık ve konum verilerini işler. '
                'Kullanmak için aşağıdaki üç onay gereklidir.',
                style: AppTypography.bodyMd.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Expanded(
                child: ListView(
                  children: [
                    _ConsentTile(
                      title: 'İlk yardım sertifikası (özel nitelikli sağlık verisi)',
                      description:
                          'Sertifika bilgilerimin doğrulama ve kayıt amacıyla işlenmesine izin veriyorum. '
                          'Detay: Aydınlatma Metni md. 2.',
                      value: _sensitiveHealth,
                      onChanged: (v) =>
                          setState(() => _sensitiveHealth = v ?? false),
                    ),
                    _ConsentTile(
                      title: 'Gerçek zamanlı ve arka plan konum',
                      description:
                          'Uygulama kapalıyken dahi konumumun yakın çağrıları size yönlendirmek için '
                          'işlenmesine ve 30 gün saklanmasına rıza veriyorum.',
                      value: _locationAlways,
                      onChanged: (v) =>
                          setState(() => _locationAlways = v ?? false),
                    ),
                    _ConsentTile(
                      title: 'Yurt dışı aktarım',
                      description:
                          'Verilerimin Google Cloud AB bölgesi (europe-west3) sunucularında işlenmesine '
                          've saklanmasına rıza veriyorum.',
                      value: _crossBorder,
                      onChanged: (v) =>
                          setState(() => _crossBorder = v ?? false),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () =>
                                context.push('/legal/aydinlatma'),
                            child: const Text('Aydınlatma Metni'),
                          ),
                        ),
                        Expanded(
                          child: TextButton(
                            onPressed: () =>
                                context.push('/legal/gizlilik'),
                            child: const Text('Gizlilik Politikası'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              PrimaryGradientButton(
                label: 'Onaylıyorum ve Devam Et',
                icon: Icons.check_rounded,
                onPressed: _canProceed ? _accept : null,
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                'Rızanızı istediğiniz zaman Profil → Gizlilik'
                ' üzerinden geri alabilirsiniz.',
                textAlign: TextAlign.center,
                style: AppTypography.labelSm.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConsentTile extends StatelessWidget {
  const _ConsentTile({
    required this.title,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String description;
  final bool value;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: value
            ? AppColors.surfaceContainerLowest
            : AppColors.surfaceContainerLow,
        borderRadius: AppSpacing.borderLg,
      ),
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: AppSpacing.borderLg,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: value,
              onChanged: onChanged,
              activeColor: AppColors.primary,
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.titleSm.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    description,
                    style: AppTypography.bodySm.copyWith(
                      color: AppColors.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
