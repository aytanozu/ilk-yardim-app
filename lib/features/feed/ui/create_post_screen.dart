import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/widgets/primary_gradient_button.dart';
import '../data/posts_repo.dart';
import '../data/storage_uploader.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _textCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _picker = ImagePicker();
  final _uploader = StorageUploader();

  File? _image;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _textCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource src) async {
    try {
      final picked = await _picker.pickImage(
        source: src,
        imageQuality: 82,
        maxWidth: 1600,
      );
      if (picked != null && mounted) {
        setState(() => _image = File(picked.path));
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Fotoğraf alınamadı: $e');
    }
  }

  Future<void> _submit() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty || text.length < 5) {
      setState(() => _error = 'Hikayenizi birkaç cümleyle paylaşın');
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _error = 'Giriş yapılmamış');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final userSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final name = userSnap.get('fullName') as String? ?? 'Gönüllü';
      final avatarUrl = userSnap.data()?['avatarUrl'] as String?;

      String? imageUrl;
      if (_image != null) {
        imageUrl = await _uploader.uploadPostImage(_image!);
      }

      await PostsRepo().createPost(
        authorId: user.uid,
        authorName: name,
        authorAvatarUrl: avatarUrl,
        text: text,
        imageUrl: imageUrl,
        location:
            _locationCtrl.text.trim().isEmpty ? null : _locationCtrl.text.trim(),
      );
      if (mounted) context.pop();
    } catch (e) {
      setState(() {
        _submitting = false;
        _error = 'Paylaşılamadı: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hikayeni Paylaş'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Topluluğu ilham verecek bir müdahale anını paylaş.',
                style: AppTypography.bodyMd.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _textCtrl,
                maxLines: 6,
                maxLength: 500,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(
                  labelText: 'Hikayen',
                  hintText:
                      'örn. Dün vapur iskelesinde bir yolcunun bilinç kaybına 6 dakikada ulaştım...',
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _locationCtrl,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Konum (opsiyonel)',
                  hintText: 'örn. Kadıköy Vapur',
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              _ImageArea(
                image: _image,
                onPickGallery: () => _pickImage(ImageSource.gallery),
                onPickCamera: () => _pickImage(ImageSource.camera),
                onRemove: () => setState(() => _image = null),
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _error!,
                  style: AppTypography.bodySm.copyWith(color: AppColors.error),
                ),
              ],
              const Spacer(),
              PrimaryGradientButton(
                label: 'Paylaş',
                icon: Icons.send_rounded,
                loading: _submitting,
                onPressed: _submitting ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImageArea extends StatelessWidget {
  const _ImageArea({
    required this.image,
    required this.onPickGallery,
    required this.onPickCamera,
    required this.onRemove,
  });

  final File? image;
  final VoidCallback onPickGallery;
  final VoidCallback onPickCamera;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    if (image != null) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: AppSpacing.borderLg,
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.file(image!, fit: BoxFit.cover),
            ),
          ),
          Positioned(
            top: AppSpacing.xs,
            right: AppSpacing.xs,
            child: Material(
              color: Colors.black.withOpacity(0.6),
              shape: const CircleBorder(),
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: onRemove,
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
        ],
      );
    }
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onPickGallery,
            icon: const Icon(Icons.photo_outlined),
            label: const Text('Galeri'),
            style: OutlinedButton.styleFrom(
              padding:
                  const EdgeInsets.symmetric(vertical: AppSpacing.md),
              side: BorderSide.none,
              backgroundColor: AppColors.surfaceContainerLow,
              shape: const RoundedRectangleBorder(
                borderRadius: AppSpacing.borderLg,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onPickCamera,
            icon: const Icon(Icons.camera_alt_outlined),
            label: const Text('Kamera'),
            style: OutlinedButton.styleFrom(
              padding:
                  const EdgeInsets.symmetric(vertical: AppSpacing.md),
              side: BorderSide.none,
              backgroundColor: AppColors.surfaceContainerLow,
              shape: const RoundedRectangleBorder(
                borderRadius: AppSpacing.borderLg,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
