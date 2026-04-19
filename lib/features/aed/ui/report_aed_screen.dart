import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../../core/location/location_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/primary_gradient_button.dart';
import '../data/aed_repo.dart';

/// Form screen for volunteers to flag a new AED location. We auto-fill
/// lat/lng from the current LocationProvider; the volunteer can adjust
/// by dragging a pin or editing the coordinates if they're not standing
/// next to the device.
class ReportAedScreen extends StatefulWidget {
  const ReportAedScreen({super.key});

  @override
  State<ReportAedScreen> createState() => _ReportAedScreenState();
}

class _ReportAedScreenState extends State<ReportAedScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _repo = AedRepo();
  bool _submitting = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit(LatLng current) async {
    if (!_formKey.currentState!.validate()) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _submitting = true);
    try {
      await _repo.submitPending(
        uid: uid,
        lat: current.latitude,
        lng: current.longitude,
        name: _nameCtrl.text,
        address: _addressCtrl.text,
        notes: _notesCtrl.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Teşekkürler — AED onay için ekibe gönderildi.'),
          backgroundColor: AppColors.tertiary,
        ),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gönderilemedi: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = context.select<LocationProvider, LatLng?>((p) => p.latLng);
    return Scaffold(
      appBar: AppBar(
        title: Text('AED Bildir',
            style: AppTypography.titleMd.copyWith(fontWeight: FontWeight.w700)),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text(
              'Yakınınızda bir otomatik eksternal defibrilatör (AED) varsa '
              'buradan bildirerek haritaya eklenmesini sağlayın. Dispatcher '
              'ekibi onayladıktan sonra tüm gönüllülere görünür olacaktır.',
              style: AppTypography.bodyMd.copyWith(
                color: AppColors.onSurfaceVariant,
                height: 1.45,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Cihazın bulunduğu yer *',
                hintText: 'Örn: Kadıköy Metro İstasyonu Gişeleri',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Gerekli' : null,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _addressCtrl,
              decoration: const InputDecoration(
                labelText: 'Açık adres *',
                hintText: 'Örn: Kadıköy Meydan, İskele yanı',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Gerekli' : null,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _notesCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Notlar (opsiyonel)',
                hintText: 'Çalışma saatleri, kat bilgisi, vs.',
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _LocationPreview(current: current),
            const SizedBox(height: AppSpacing.lg),
            PrimaryGradientButton(
              label: _submitting ? 'Gönderiliyor…' : 'Onaya Gönder',
              icon: Icons.send_rounded,
              onPressed: (_submitting || current == null)
                  ? null
                  : () => _submit(current),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationPreview extends StatelessWidget {
  const _LocationPreview({required this.current});
  final LatLng? current;

  @override
  Widget build(BuildContext context) {
    if (current == null) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: AppSpacing.borderLg,
        ),
        child: Text(
          'Konum alınamadı. Konum servisinin açık olduğundan emin olun.',
          style: AppTypography.bodySm.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: AppSpacing.borderLg,
      ),
      child: Row(
        children: [
          const Icon(Icons.location_on_rounded,
              color: AppColors.tertiary, size: 20),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              'Mevcut konum: '
              '${current!.latitude.toStringAsFixed(5)}, '
              '${current!.longitude.toStringAsFixed(5)}',
              style: AppTypography.bodySm.copyWith(
                color: AppColors.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
