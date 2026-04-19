import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/primary_gradient_button.dart';
import '../providers/auth_provider.dart';

class OtpVerifyScreen extends StatefulWidget {
  const OtpVerifyScreen({super.key});

  @override
  State<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends State<OtpVerifyScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final finalizing = auth.stage == AuthStage.finalizing;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.read<AuthProvider>().resetToPhoneEntry(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SMS Doğrulaması',
                style: AppTypography.displaySm.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '${auth.phoneE164 ?? ''} numarasına 6 haneli kod gönderildi.',
                style: AppTypography.bodyMd.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              TextField(
                controller: _controller,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                textAlign: TextAlign.center,
                style: AppTypography.displaySm.copyWith(letterSpacing: 12),
                onChanged: (v) {
                  if (v.length == 6) {
                    context.read<AuthProvider>().submitOtp(v);
                  }
                  setState(() {});
                },
                decoration: const InputDecoration(labelText: 'Doğrulama Kodu'),
              ),
              if (auth.lastError != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  auth.lastError!,
                  style: AppTypography.bodySm.copyWith(color: AppColors.error),
                ),
              ],
              const Spacer(),
              PrimaryGradientButton(
                label: 'Doğrula',
                loading: finalizing,
                onPressed: _controller.text.length == 6 && !finalizing
                    ? () =>
                        context.read<AuthProvider>().submitOtp(_controller.text)
                    : null,
              ),
              const SizedBox(height: AppSpacing.md),
              Center(
                child: TextButton(
                  onPressed: () =>
                      context.read<AuthProvider>().resetToPhoneEntry(),
                  child: const Text('Numarayı değiştir'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
