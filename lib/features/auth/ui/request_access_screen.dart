import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/tc_kimlik.dart';
import '../../../shared/widgets/primary_gradient_button.dart';

/// Pre-authentication self-registration flow. Reached from the
/// NotCertifiedScreen by users who have completed phone OTP but aren't
/// on the allowlist yet. We write a `registration_requests` doc with a
/// photo of their certificate; a dispatcher reviews it via the admin
/// panel and a Cloud Function promotes them to `certified_phones`.
class RequestAccessScreen extends StatefulWidget {
  const RequestAccessScreen({super.key});

  @override
  State<RequestAccessScreen> createState() => _RequestAccessScreenState();
}

class _RequestAccessScreenState extends State<RequestAccessScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _tcKimlik = TextEditingController();
  final _certId = TextEditingController();
  final _issuer = TextEditingController(text: 'Sağlık Bakanlığı Onaylı');
  final _city = TextEditingController();
  final _district = TextEditingController();
  DateTime? _expiresAt;
  XFile? _photo;
  bool _submitting = false;

  @override
  void dispose() {
    _name.dispose();
    _tcKimlik.dispose();
    _certId.dispose();
    _issuer.dispose();
    _city.dispose();
    _district.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
      maxWidth: 1800,
    );
    if (file == null) return;
    setState(() => _photo = file);
  }

  Future<void> _pickExpiryDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 365)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 5)),
    );
    if (picked != null) setState(() => _expiresAt = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_photo == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Sertifika fotoğrafı ekleyin.'),
      ));
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.phoneNumber == null) return;

    setState(() => _submitting = true);
    try {
      // Upload the certificate photo first. Storage rules scope writes
      // to /registration_docs/{uid}/.
      final ts = DateTime.now().millisecondsSinceEpoch;
      final ref = FirebaseStorage.instance
          .ref('registration_docs/${user.uid}/$ts.jpg');
      await ref.putFile(File(_photo!.path));
      final photoUrl = await ref.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('registration_requests')
          .add({
        'phone': user.phoneNumber,
        'fullName': _name.text.trim(),
        'tcKimlik': _tcKimlik.text.trim(),
        'certificateId': _certId.text.trim(),
        'certificateType': 'İleri İlkyardım Sertifikası',
        'issuer': _issuer.text.trim(),
        'region': {
          'country': 'TR',
          'city': _city.text.trim().toLowerCase(),
          'district': _district.text.trim().toLowerCase(),
        },
        'roleLabel': 'Gönüllü',
        'expiresAt': _expiresAt == null
            ? null
            : Timestamp.fromDate(_expiresAt!),
        'certificateImageUrl': photoUrl,
        'submittedByUid': user.uid,
        'status': 'pending',
        'submittedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Başvurunuz alındı. Sonucunu SMS ile bildireceğiz.'),
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
    final phone = FirebaseAuth.instance.currentUser?.phoneNumber ?? '—';
    return Scaffold(
      appBar: AppBar(
        title: Text('Başvuru',
            style: AppTypography.titleMd.copyWith(fontWeight: FontWeight.w700)),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text(
              'Telefon: $phone',
              style: AppTypography.bodySm.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Ad Soyad *'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Gerekli' : null,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              controller: _tcKimlik,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'TC Kimlik No *',
                helperText: '11 haneli, kimlik kartınızda yazan numara',
              ),
              validator: validateTcKimlik,
              maxLength: 11,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              controller: _certId,
              decoration: const InputDecoration(labelText: 'Sertifika No *'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Gerekli' : null,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              controller: _issuer,
              decoration: const InputDecoration(
                labelText: 'Eğitim Merkezi / Veren Kurum',
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _city,
                    decoration: const InputDecoration(labelText: 'Şehir *'),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Gerekli' : null,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: TextFormField(
                    controller: _district,
                    decoration: const InputDecoration(labelText: 'İlçe *'),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Gerekli' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            InkWell(
              onTap: _pickExpiryDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Son Kullanma Tarihi',
                  suffixIcon: Icon(Icons.calendar_today_rounded, size: 18),
                ),
                child: Text(
                  _expiresAt == null
                      ? 'Tarih seçin'
                      : '${_expiresAt!.day}/${_expiresAt!.month}/${_expiresAt!.year}',
                  style: AppTypography.bodyMd,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _PhotoUploader(photo: _photo, onPick: _pickPhoto),
            const SizedBox(height: AppSpacing.lg),
            PrimaryGradientButton(
              label: _submitting ? 'Gönderiliyor…' : 'Başvuruyu Gönder',
              icon: Icons.send_rounded,
              onPressed: _submitting ? null : _submit,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Başvurunuz incelendikten sonra telefonunuza kısa mesaj ile '
              'sonuç bildirilir. Genellikle 24 saat içinde dönüş yaparız.',
              style: AppTypography.labelSm.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoUploader extends StatelessWidget {
  const _PhotoUploader({required this.photo, required this.onPick});
  final XFile? photo;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: AppSpacing.borderLg,
      onTap: onPick,
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: AppSpacing.borderLg,
          border: Border.all(color: AppColors.onSurfaceVariant, width: 1),
        ),
        child: photo == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_a_photo_rounded,
                      size: 36, color: AppColors.primary),
                  const SizedBox(height: AppSpacing.xs),
                  Text('Sertifika fotoğrafı ekle',
                      style: AppTypography.bodyMd
                          .copyWith(color: AppColors.onSurface)),
                  Text('(kameradan)',
                      style: AppTypography.labelSm
                          .copyWith(color: AppColors.onSurfaceVariant)),
                ],
              )
            : ClipRRect(
                borderRadius: AppSpacing.borderLg,
                child: Image.file(File(photo!.path), fit: BoxFit.cover),
              ),
      ),
    );
  }
}
