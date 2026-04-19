import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/settings_row.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Gizlilik ve KVKK',
          style: AppTypography.titleMd.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.xxl,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.md,
            ),
            child: Text(
              'Verilerinizin nasıl işlendiğini açıklayan KVKK kapsamındaki '
              'belgeler aşağıda yer almaktadır.',
              style: AppTypography.bodyMd.copyWith(
                color: AppColors.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ),
          SettingsRow(
            icon: Icons.description_outlined,
            label: 'Aydınlatma Metni',
            subtitle: 'KVKK md. 10 kapsamında bilgilendirme',
            onTap: () => context.push('/legal/aydinlatma'),
          ),
          SettingsRow(
            icon: Icons.shield_outlined,
            label: 'Gizlilik Politikası',
            subtitle: 'Toplanan veriler ve saklama süreleri',
            onTap: () => context.push('/legal/gizlilik'),
          ),
          SettingsRow(
            icon: Icons.verified_user_outlined,
            label: 'Açık Rıza Metni',
            subtitle: 'Onayladığınız özel nitelikli veri işlemleri',
            onTap: () => context.push('/legal/riza'),
          ),
          SettingsRow(
            icon: Icons.gavel_outlined,
            label: 'Kullanım Koşulları',
            subtitle: 'Sertifika, sorumluluk ve kullanım şartları',
            onTap: () => context.push('/legal/kullanim'),
          ),
        ],
      ),
    );
  }
}
