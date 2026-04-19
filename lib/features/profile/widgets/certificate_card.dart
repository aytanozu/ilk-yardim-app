import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/models/user_profile.dart';

class CertificateCard extends StatelessWidget {
  const CertificateCard({super.key, required this.certificate});

  final CertificateInfo certificate;

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('d MMM yyyy', 'tr_TR');
    final expiring =
        certificate.expiresAt.difference(DateTime.now()).inDays < 30;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: AppSpacing.borderXl,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.surfaceContainerLowest,
            AppColors.tertiaryFixedDim.withOpacity(0.15),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.verified_user_rounded,
                color: AppColors.tertiary,
                size: 22,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'Sertifika Bilgileri',
                style: AppTypography.labelMd.copyWith(
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            certificate.type,
            style: AppTypography.titleLg.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            certificate.issuer,
            style: AppTypography.bodySm
                .copyWith(color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Icon(
                expiring
                    ? Icons.warning_amber_rounded
                    : Icons.event_available_rounded,
                size: 18,
                color: expiring ? AppColors.error : AppColors.tertiary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'Geçerlilik: ${df.format(certificate.expiresAt)}',
                style: AppTypography.bodyMd.copyWith(
                  fontWeight: FontWeight.w600,
                  color:
                      expiring ? AppColors.error : AppColors.onSurface,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
