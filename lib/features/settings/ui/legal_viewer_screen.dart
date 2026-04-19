import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

class LegalDoc {
  const LegalDoc(this.title, this.assetPath);
  final String title;
  final String assetPath;
}

/// Maps short URL keys to titles + asset paths for the four KVKK docs
/// bundled under /legal in pubspec.yaml.
const Map<String, LegalDoc> kLegalDocs = {
  'aydinlatma': LegalDoc('Aydınlatma Metni', 'legal/aydinlatma_metni.md'),
  'gizlilik': LegalDoc('Gizlilik Politikası', 'legal/gizlilik_politikasi.md'),
  'riza': LegalDoc('Açık Rıza Metni', 'legal/acik_riza_metni.md'),
  'kullanim': LegalDoc('Kullanım Koşulları', 'legal/kullanim_kosullari.md'),
};

class LegalViewerScreen extends StatelessWidget {
  const LegalViewerScreen({super.key, required this.docKey});

  final String docKey;

  @override
  Widget build(BuildContext context) {
    final doc = kLegalDocs[docKey];
    return Scaffold(
      appBar: AppBar(
        title: Text(doc?.title ?? 'Belge',
            style: AppTypography.titleMd.copyWith(fontWeight: FontWeight.w700)),
      ),
      body: doc == null
          ? const Center(child: Text('Belge bulunamadı.'))
          : FutureBuilder<String>(
              future: rootBundle.loadString(doc.assetPath),
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(
                    child:
                        CircularProgressIndicator(color: AppColors.primary),
                  );
                }
                if (snap.hasError || !snap.hasData) {
                  return const Center(
                    child: Text('Belge yüklenemedi.'),
                  );
                }
                return Markdown(
                  data: snap.data!,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  styleSheet: _buildStyleSheet(context),
                );
              },
            ),
    );
  }

  MarkdownStyleSheet _buildStyleSheet(BuildContext context) {
    return MarkdownStyleSheet(
      h1: AppTypography.headlineSm.copyWith(fontWeight: FontWeight.w800),
      h2: AppTypography.titleLg.copyWith(fontWeight: FontWeight.w700),
      h3: AppTypography.titleMd.copyWith(fontWeight: FontWeight.w700),
      p: AppTypography.bodyMd.copyWith(height: 1.6),
      strong: AppTypography.bodyMd.copyWith(
        fontWeight: FontWeight.w700,
      ),
      listBullet: AppTypography.bodyMd.copyWith(height: 1.6),
      blockSpacing: AppSpacing.md,
      h1Padding: const EdgeInsets.only(top: AppSpacing.md),
      h2Padding: const EdgeInsets.only(top: AppSpacing.md),
    );
  }
}
