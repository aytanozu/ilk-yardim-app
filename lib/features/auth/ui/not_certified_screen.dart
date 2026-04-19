import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/primary_gradient_button.dart';
import '../providers/auth_provider.dart';

class NotCertifiedScreen extends StatelessWidget {
  const NotCertifiedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final reason = context.select<AuthProvider, String?>(
      (p) => p.notCertifiedReason,
    );

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.primaryFixed,
                  borderRadius: AppSpacing.borderFull,
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  color: AppColors.primary,
                  size: 36,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                _title(reason),
                style: AppTypography.displaySm.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.08,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                _body(reason),
                style: AppTypography.bodyMd.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const Spacer(flex: 2),
              PrimaryGradientButton(
                label: 'Farklı Numara Dene',
                icon: Icons.refresh_rounded,
                onPressed: () =>
                    context.read<AuthProvider>().resetToPhoneEntry(),
              ),
              const SizedBox(height: AppSpacing.sm),
              Center(
                child: TextButton(
                  onPressed: () {},
                  child: Text(
                    'Destek ile iletişim',
                    style: AppTypography.labelMd
                        .copyWith(color: AppColors.secondary),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _title(String? reason) {
    switch (reason) {
      case 'expired':
        return 'Sertifikanızın Süresi Dolmuş';
      case 'not_found':
        return 'Kayıtlı Sertifika\nBulunamadı';
      case 'invalid_format':
        return 'Geçersiz Numara';
      default:
        return 'Giriş Yapılamadı';
    }
  }

  String _body(String? reason) {
    switch (reason) {
      case 'expired':
        return 'Sertifikanızın geçerlilik süresi sona erdi. Lütfen sertifika yenilemenizi tamamladıktan sonra tekrar deneyin.';
      case 'not_found':
        return 'Bu telefon numarasına kayıtlı, Sağlık Bakanlığı onaylı aktif bir ilk yardım sertifikası bulamadık. Numaranızı kontrol edin veya destek ile iletişime geçin.';
      case 'network':
        return 'İnternet bağlantınızı kontrol edip tekrar deneyin.';
      default:
        return 'Girişinizi tamamlayamadık. Tekrar deneyin, sorun sürerse destek ile iletişime geçin.';
    }
  }
}
