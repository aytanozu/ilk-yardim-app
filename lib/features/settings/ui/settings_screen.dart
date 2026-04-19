import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/location/background_service_runner.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/models/user_profile.dart';
import '../../../shared/widgets/settings_row.dart';
import '../../auth/providers/auth_provider.dart';

const String kLocationSharingPrefKey = 'location_sharing_enabled';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _locationSharing = true;
  String _version = '';

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() {
      _locationSharing = prefs.getBool(kLocationSharingPrefKey) ?? true;
      _version = '${info.version} (${info.buildNumber})';
    });
  }

  Future<void> _setLocationSharing(bool value) async {
    setState(() => _locationSharing = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kLocationSharingPrefKey, value);
    if (value) {
      await BackgroundServiceRunner.instance.start();
    } else {
      await BackgroundServiceRunner.instance.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile =
        context.select<AuthProvider, UserProfile?>((p) => p.profile);
    final available = profile?.available ?? true;
    final criticalOnly = profile?.notificationPrefs.criticalOnly ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Ayarlar',
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
          _SectionHeader(
            icon: Icons.flash_on_rounded,
            title: 'Uygunluk',
          ),
          SettingsRow(
            icon: Icons.notifications_active_rounded,
            label: 'Çağrı almaya uygunum',
            subtitle: available
                ? 'Çevredeki çağrılar bildirilecek'
                : 'Yeni çağrılar size iletilmeyecek',
            onTap: () {
              context.read<AuthProvider>().setAvailable(!available);
            },
            trailing: Switch.adaptive(
              value: available,
              onChanged: (v) =>
                  context.read<AuthProvider>().setAvailable(v),
            ),
          ),
          const Divider(height: AppSpacing.lg),
          _SectionHeader(
            icon: Icons.tune_rounded,
            title: 'Bildirimler',
          ),
          SettingsRow(
            icon: Icons.priority_high_rounded,
            label: 'Yalnız kritik çağrılar',
            subtitle:
                'Kalp krizi, bilinç kaybı gibi kritik vakalar dışındaki bildirimleri kapat',
            onTap: () {
              context
                  .read<AuthProvider>()
                  .updateNotificationPrefs(criticalOnly: !criticalOnly);
            },
            trailing: Switch.adaptive(
              value: criticalOnly,
              onChanged: (v) => context
                  .read<AuthProvider>()
                  .updateNotificationPrefs(criticalOnly: v),
            ),
          ),
          const Divider(height: AppSpacing.lg),
          _SectionHeader(
            icon: Icons.person_outline_rounded,
            title: 'Profil',
          ),
          SettingsRow(
            icon: Icons.edit_rounded,
            label: 'Adı ve bölgeyi düzenle',
            subtitle: profile == null
                ? ''
                : '${profile.fullName} · ${profile.region.city}',
            onTap: () => _editProfile(context, profile),
          ),
          const Divider(height: AppSpacing.lg),
          _SectionHeader(
            icon: Icons.location_on_outlined,
            title: 'Konum paylaşımı',
          ),
          SettingsRow(
            icon: Icons.gps_fixed_rounded,
            label: 'Arka plan konum paylaşımı',
            subtitle: _locationSharing
                ? 'Uygulama kapalıyken de konum paylaşılıyor'
                : 'Konum paylaşımı durduruldu — çağrı alamazsınız',
            onTap: () => _setLocationSharing(!_locationSharing),
            trailing: Switch.adaptive(
              value: _locationSharing,
              onChanged: _setLocationSharing,
            ),
          ),
          const Divider(height: AppSpacing.lg),
          _SectionHeader(
            icon: Icons.info_outline_rounded,
            title: 'Uygulama',
          ),
          SettingsRow(
            icon: Icons.privacy_tip_outlined,
            label: 'Gizlilik ve KVKK',
            onTap: () => context.push('/privacy'),
          ),
          SettingsRow(
            icon: Icons.numbers_rounded,
            label: 'Sürüm',
            subtitle: _version.isEmpty ? '—' : _version,
            onTap: () {},
            trailing: const SizedBox.shrink(),
          ),
          SettingsRow(
            icon: Icons.delete_outline_rounded,
            label: 'Hesabı sil',
            subtitle: 'Hesap silme talebi ekibe iletilir',
            onTap: () => _requestAccountDeletion(context),
            color: AppColors.error,
          ),
          SettingsRow(
            icon: Icons.logout_rounded,
            label: 'Çıkış Yap',
            onTap: () => context.read<AuthProvider>().signOut(),
            color: AppColors.error,
          ),
        ],
      ),
    );
  }

  Future<void> _editProfile(BuildContext context, UserProfile? profile) async {
    if (profile == null) return;
    final nameCtrl = TextEditingController(text: profile.fullName);
    final cityCtrl = TextEditingController(text: profile.region.city);
    final districtCtrl = TextEditingController(text: profile.region.district);

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Profili düzenle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Ad Soyad'),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: cityCtrl,
              decoration: const InputDecoration(labelText: 'Şehir'),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: districtCtrl,
              decoration: const InputDecoration(labelText: 'İlçe'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );

    if (saved != true || !context.mounted) return;
    await context.read<AuthProvider>().updateProfile(
          fullName: nameCtrl.text.trim(),
          region: {
            'country': profile.region.country,
            'city': cityCtrl.text.trim(),
            'district': districtCtrl.text.trim(),
          },
        );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profil güncellendi')),
    );
  }

  Future<void> _requestAccountDeletion(BuildContext context) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hesabı sil?'),
        content: const Text(
          'Hesap silme talebiniz ekibe iletilir. İşlem genellikle '
          '30 gün içinde tamamlanır. Bu süre içinde vazgeçebilirsiniz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Talep et'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;
    await FirebaseFirestore.instance
        .collection('account_deletion_requests')
        .doc(uid)
        .set({
      'uid': uid,
      'requestedAt': FieldValue.serverTimestamp(),
      'status': 'pending',
    });
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Silme talebiniz alındı')),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.title});
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.xs,
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.onSurfaceVariant),
          const SizedBox(width: AppSpacing.xs),
          Text(
            title.toUpperCase(),
            style: AppTypography.labelSm.copyWith(
              color: AppColors.onSurfaceVariant,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
