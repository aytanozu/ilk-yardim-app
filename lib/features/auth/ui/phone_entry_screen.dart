import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/primary_gradient_button.dart';
import '../providers/auth_provider.dart';

class PhoneEntryScreen extends StatefulWidget {
  const PhoneEntryScreen({super.key});

  @override
  State<PhoneEntryScreen> createState() => _PhoneEntryScreenState();
}

class _PhoneEntryScreenState extends State<PhoneEntryScreen> {
  final _controller = TextEditingController();
  bool _submitting = false;

  String get _rawDigits =>
      _controller.text.replaceAll(RegExp(r'\D'), '').trimLeft();

  bool get _isValid => _rawDigits.length == 10 && _rawDigits.startsWith('5');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_isValid) return;
    setState(() => _submitting = true);
    final phoneE164 = '+90$_rawDigits';
    await context.read<AuthProvider>().submitPhone(phoneE164);
    if (mounted) setState(() => _submitting = false);
  }

  @override
  Widget build(BuildContext context) {
    final lastError = context.select<AuthProvider, String?>(
      (p) => p.lastError,
    );

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.xl),
              Text(
                'KLİNİK NABIZ',
                style: AppTypography.labelMd.copyWith(
                  color: AppColors.primary,
                  letterSpacing: 3,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Sertifikalı\nGönüllü Girişi',
                style: AppTypography.displaySm.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.05,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Sağlık Bakanlığı onaylı ilk yardım sertifikası olan '
                'gönüllülere açık bir platformdur.',
                style: AppTypography.bodyMd.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              TextField(
                controller: _controller,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                  _TrPhoneFormatter(),
                ],
                onChanged: (_) => setState(() {}),
                style: AppTypography.titleLg,
                decoration: const InputDecoration(
                  labelText: 'Cep Telefonu',
                  prefixText: '+90 ',
                  hintText: '5XX XXX XX XX',
                ),
              ),
              if (lastError != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  lastError,
                  style: AppTypography.bodySm.copyWith(color: AppColors.error),
                ),
              ],
              const Spacer(),
              PrimaryGradientButton(
                label: 'Devam Et',
                trailingIcon: Icons.arrow_forward_rounded,
                loading: _submitting,
                onPressed: _isValid && !_submitting ? _submit : null,
              ),
              const SizedBox(height: AppSpacing.sm),
              Center(
                child: TextButton(
                  onPressed: () {},
                  child: Text(
                    'Sertifikam yok ama katılmak istiyorum',
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
}

class _TrPhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buf = StringBuffer();
    for (var i = 0; i < digits.length && i < 10; i++) {
      if (i == 3 || i == 6 || i == 8) buf.write(' ');
      buf.write(digits[i]);
    }
    return TextEditingValue(
      text: buf.toString(),
      selection: TextSelection.collapsed(offset: buf.length),
    );
  }
}
