import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../../core/location/location_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/nav_launcher.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/models/emergency_case.dart';
import '../../../shared/widgets/primary_gradient_button.dart';
import '../data/emergency_repo.dart';
import '../providers/accepted_case_notifier.dart';

/// Full-screen dramatic alert screen reached via push-notification deep link.
/// Designed to wake a phone from a volunteer's pocket: large type,
/// minimal chrome, single action.
class EmergencyDetailScreen extends StatefulWidget {
  const EmergencyDetailScreen({super.key, required this.emergencyId});
  final String emergencyId;

  @override
  State<EmergencyDetailScreen> createState() => _EmergencyDetailScreenState();
}

class _EmergencyDetailScreenState extends State<EmergencyDetailScreen> {
  final _repo = EmergencyRepo();
  bool _accepting = false;
  bool _leavingAfterAccept = false;

  @override
  void initState() {
    super.initState();
    HapticFeedback.heavyImpact();
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
  }

  Future<void> _accept(EmergencyCase c) async {
    debugPrint('[Emergency] accept tapped id=${c.id}');
    setState(() => _accepting = true);
    try {
      await _repo.accept(c.id);
      debugPrint('[Emergency] accept OK id=${c.id}');
      if (!mounted) return;
      setState(() => _leavingAfterAccept = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Çağrı kabul edildi — yolda başarılar'),
          backgroundColor: AppColors.tertiary,
        ),
      );
      // Launch native walking navigation (Google Maps / Apple Maps) and
      // also return to our map with the route pre-selected.
      AcceptedCaseNotifier.instance.set(c.id);
      unawaited(NavLauncher.openWalking(
        lat: c.location.latitude,
        lng: c.location.longitude,
        label: c.address,
      ));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/');
      });
    } catch (e, s) {
      debugPrint('[Emergency] accept FAILED id=${c.id} err=$e\n$s');
      if (mounted) {
        final code = e.toString();
        final raced = code.contains('failed-precondition');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(raced
                ? 'Başka bir gönüllü daha hızlı davrandı.'
                : 'Kabul edilemedi: $code'),
            backgroundColor: raced ? AppColors.tertiary : AppColors.error,
            duration: const Duration(seconds: 5),
          ),
        );
        if (raced) context.go('/');
      }
    } finally {
      if (mounted) setState(() => _accepting = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    return StreamBuilder<EmergencyCase?>(
      stream: _repo.watchCase(widget.emergencyId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final c = snap.data;
        if (c == null) return _notFound(context);
        // If we just accepted this and stream pushed the updated status,
        // keep showing a "yolda başarılar" state until the scheduled
        // navigation to / fires on next frame.
        return _DetailBody(
          emergency: c,
          accepting: _accepting,
          onAccept: () => _accept(c),
          onDismiss: () => context.go('/'),
          acceptedByMe: _leavingAfterAccept ||
              c.acceptedBy == FirebaseAuth.instance.currentUser?.uid,
        );
      },
    );
  }

  Widget _notFound(BuildContext context) => Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.info_outline_rounded,
                    size: 56, color: AppColors.onSurfaceVariant),
                const SizedBox(height: AppSpacing.sm),
                Text('Çağrı artık aktif değil',
                    style: AppTypography.titleLg
                        .copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: AppSpacing.sm),
                FilledButton(
                  onPressed: () => context.go('/'),
                  child: const Text('Haritaya dön'),
                ),
              ],
            ),
          ),
        ),
      );
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({
    required this.emergency,
    required this.accepting,
    required this.onAccept,
    required this.onDismiss,
    required this.acceptedByMe,
  });

  final EmergencyCase emergency;
  final bool accepting;
  final VoidCallback onAccept;
  final VoidCallback onDismiss;
  final bool acceptedByMe;

  Color get _severityColor {
    switch (emergency.severity) {
      case Severity.critical:
        return AppColors.severityCritical;
      case Severity.serious:
        return AppColors.severitySerious;
      case Severity.minor:
        return AppColors.severityMinor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.select<LocationProvider, LatLng?>((p) => p.latLng);
    double? distanceM;
    if (loc != null) {
      distanceM = const Distance().as(
        LengthUnit.Meter,
        loc,
        LatLng(emergency.location.latitude, emergency.location.longitude),
      );
    }
    final distLabel = distanceM == null
        ? '—'
        : distanceM < 1000
            ? '${distanceM.round()} m'
            : '${(distanceM / 1000).toStringAsFixed(1)} km';

    final alreadyTaken = emergency.status != EmergencyStatus.open;

    return Scaffold(
      backgroundColor: _severityColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.xs),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.22),
                      borderRadius: AppSpacing.borderFull,
                    ),
                    child: const Icon(Icons.warning_amber_rounded,
                        color: Colors.white),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    _severityHeader(emergency.severity),
                    style: AppTypography.labelMd.copyWith(
                      color: Colors.white,
                      letterSpacing: 3,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: onDismiss,
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                emergency.type.turkish,
                style: AppTypography.displayMd.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  height: 1.05,
                  letterSpacing: -1.5,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                emergency.address,
                style: AppTypography.titleMd.copyWith(
                  color: Colors.white.withOpacity(0.92),
                  height: 1.3,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  _MetricBox(
                    label: 'MESAFE',
                    value: distLabel,
                    icon: Icons.directions_walk_rounded,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _MetricBox(
                    label: 'DURUM',
                    value: alreadyTaken
                        ? (emergency.status == EmergencyStatus.accepted
                            ? 'Müdahalede'
                            : 'Kapalı')
                        : 'AÇIK',
                    icon: Icons.access_time_rounded,
                  ),
                ],
              ),
              if (emergency.description.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.18),
                    borderRadius: AppSpacing.borderLg,
                  ),
                  child: Text(
                    emergency.description,
                    style: AppTypography.bodyLg.copyWith(
                      color: Colors.white,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
              if (emergency.hazards.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: emergency.hazards
                      .map((h) => _HazardPill(label: _hazardTr(h)))
                      .toList(),
                ),
              ],
              const Spacer(),
              if (alreadyTaken)
                _ClosedBanner(
                  status: emergency.status,
                  acceptedByMe: acceptedByMe,
                )
              else
                _AcceptBar(
                  onAccept: accepting ? null : onAccept,
                  onDismiss: onDismiss,
                  loading: accepting,
                ),
            ],
          ),
        ),
      ),
    );
  }

  static String _severityHeader(Severity s) {
    switch (s) {
      case Severity.critical:
        return 'KRİTİK ACİL ÇAĞRI';
      case Severity.serious:
        return 'ACİL ÇAĞRI';
      case Severity.minor:
        return 'YARDIM ÇAĞRISI';
    }
  }

  static String _hazardTr(String k) {
    switch (k) {
      case 'fire':
        return '🔥 Yangın';
      case 'traffic':
        return '🚗 Trafik';
      case 'attacker':
        return '⚠️ Saldırgan';
      case 'electric':
        return '⚡ Elektrik';
      case 'chemical':
        return '☣️ Kimyasal';
      default:
        return k;
    }
  }
}

class _MetricBox extends StatelessWidget {
  const _MetricBox(
      {required this.label, required this.value, required this.icon});
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.18),
          borderRadius: AppSpacing.borderLg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.white, size: 14),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: AppTypography.labelSm.copyWith(
                    color: Colors.white.withOpacity(0.7),
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: AppTypography.headlineSm.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HazardPill extends StatelessWidget {
  const _HazardPill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppSpacing.borderFull,
      ),
      child: Text(
        label,
        style: AppTypography.labelMd.copyWith(
          color: AppColors.onSurface,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _AcceptBar extends StatelessWidget {
  const _AcceptBar(
      {required this.onAccept, required this.onDismiss, required this.loading});
  final VoidCallback? onAccept;
  final VoidCallback onDismiss;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: AppSpacing.borderFull,
            color: Colors.white,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onAccept,
              borderRadius: AppSpacing.borderFull,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg, vertical: AppSpacing.md + 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (loading)
                      const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: AppColors.primary,
                        ),
                      )
                    else
                      const Icon(
                        Icons.emergency_rounded,
                        color: AppColors.primary,
                      ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'YARDIMA GİT',
                      style: AppTypography.titleMd.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        TextButton(
          onPressed: onDismiss,
          child: Text(
            'Şimdi müsait değilim',
            style: AppTypography.labelLg.copyWith(
              color: Colors.white.withOpacity(0.9),
            ),
          ),
        ),
      ],
    );
  }
}

class _ClosedBanner extends StatelessWidget {
  const _ClosedBanner({required this.status, required this.acceptedByMe});
  final EmergencyStatus status;
  final bool acceptedByMe;

  @override
  Widget build(BuildContext context) {
    final label = acceptedByMe
        ? 'Çağrı kabul edildi. Haritaya yönlendiriliyorsunuz…'
        : status == EmergencyStatus.accepted
            ? 'Bu çağrıyı başka bir gönüllü üstlendi. Teşekkürler.'
            : 'Bu çağrı artık aktif değil.';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: AppSpacing.borderLg,
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: AppTypography.bodyMd.copyWith(color: Colors.white),
      ),
    );
  }
}

