import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../../core/location/location_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/models/emergency_case.dart';
import '../../../shared/widgets/glass_fab.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/emergency_repo.dart';
import '../data/routing_service.dart';
import '../providers/accepted_case_notifier.dart';
import '../widgets/emergency_alert_card.dart';

class EmergencyMapScreen extends StatefulWidget {
  const EmergencyMapScreen({super.key});

  @override
  State<EmergencyMapScreen> createState() => _EmergencyMapScreenState();
}

class _EmergencyMapScreenState extends State<EmergencyMapScreen> {
  final _mapController = MapController();
  final _repo = EmergencyRepo();
  final _router = RoutingService();

  EmergencyCase? _selected;
  RouteResult? _route;
  bool _accepting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<LocationProvider>().start(requestAlways: true);
      _autoSelectAcceptedCase();
    });
    AcceptedCaseNotifier.instance.addListener(_autoSelectAcceptedCase);
  }

  @override
  void dispose() {
    AcceptedCaseNotifier.instance.removeListener(_autoSelectAcceptedCase);
    super.dispose();
  }

  Future<void> _autoSelectAcceptedCase() async {
    final id = AcceptedCaseNotifier.instance.value;
    if (id == null) return;
    AcceptedCaseNotifier.instance.clear(); // one-shot

    try {
      final snap = await FirebaseFirestore.instance
          .collection('emergencies')
          .doc(id)
          .get();
      if (!snap.exists) return;
      final c = EmergencyCase.fromSnapshot(snap);
      if (!mounted) return;
      setState(() => _selected = c);

      final loc = context.read<LocationProvider>().latLng;
      if (loc == null) return;
      final target = LatLng(c.location.latitude, c.location.longitude);
      final route = await _router.route(from: loc, to: target);
      if (!mounted || route == null) return;
      setState(() => _route = route);
      _mapController.fitCamera(
        CameraFit.coordinates(
          coordinates: [loc, target],
          padding: const EdgeInsets.all(72),
        ),
      );
    } catch (e) {
      debugPrint('autoSelectAcceptedCase failed: $e');
    }
  }

  Future<void> _onAccept(EmergencyCase e) async {
    setState(() => _accepting = true);
    try {
      await _repo.accept(e.id);
      final loc = context.read<LocationProvider>().latLng;
      if (loc != null) {
        final target = LatLng(e.location.latitude, e.location.longitude);
        final route = await _router.route(from: loc, to: target);
        if (mounted) setState(() => _route = route);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Çağrı kabul edildi — yolda başarılar')),
        );
      }
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kabul edilemedi: $err')),
        );
      }
    } finally {
      if (mounted) setState(() => _accepting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final city = context.select<AuthProvider, String>(
      (p) => p.profile?.region.city ?? 'istanbul',
    );

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          'KLİNİK NABIZ',
          style: AppTypography.titleMd.copyWith(letterSpacing: 3),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: AppSpacing.sm),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xxs,
            ),
            decoration: BoxDecoration(
              color: AppColors.tertiary.withOpacity(0.12),
              borderRadius: AppSpacing.borderFull,
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.tertiary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: AppSpacing.xxs),
                Text(
                  'Aktif',
                  style: AppTypography.labelSm.copyWith(
                    color: AppColors.tertiary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          StreamBuilder<List<EmergencyCase>>(
            stream: _repo.watchOpenCasesForCity(city),
            builder: (context, snap) {
              final cases = snap.data ?? [];
              return _MapView(
                controller: _mapController,
                cases: cases,
                route: _route,
                selectedId: _selected?.id,
                onMarkerTap: (e) {
                  setState(() => _selected = e);
                },
              );
            },
          ),
          if (_selected != null)
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _buildAlertCard(_selected!),
                ),
              ),
            ),
          Positioned(
            right: AppSpacing.md,
            bottom: MediaQuery.of(context).padding.bottom + 120,
            child: GlassFab(
              icon: Icons.emergency_rounded,
              onPressed: _centerOnUser,
              pulse: _selected == null,
              label: 'Konumuma git',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertCard(EmergencyCase e) {
    final loc = context.watch<LocationProvider>().latLng;
    double? distance;
    if (loc != null) {
      final d = const Distance().as(
        LengthUnit.Meter,
        loc,
        LatLng(e.location.latitude, e.location.longitude),
      );
      distance = d;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: EmergencyAlertCard(
        emergency: e,
        distanceMeters: distance,
        etaSeconds: _route?.durationSeconds ?? _estimateEta(distance),
        onAccept: _accepting ? () {} : () => _onAccept(e),
        onDetails: () => _showDetails(e),
      ),
    );
  }

  double? _estimateEta(double? meters) {
    if (meters == null) return null;
    // ~5 m/s walking pace
    return meters / 5.0;
  }

  void _centerOnUser() {
    final p = context.read<LocationProvider>().latLng;
    if (p != null) _mapController.move(p, 15);
  }

  void _showDetails(EmergencyCase e) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(e.type.turkish,
                style: AppTypography.headlineSm
                    .copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: AppSpacing.sm),
            Text(e.description, style: AppTypography.bodyMd),
            const SizedBox(height: AppSpacing.sm),
            Text('Adres: ${e.address}', style: AppTypography.bodySm),
            if (e.patient != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text('Hasta: ${e.patient!.age ?? '?'} yaş, '
                  '${e.patient!.gender ?? 'belirtilmemiş'}'),
              if (e.patient!.consciousness != null)
                Text('Bilinç: ${e.patient!.consciousness!}'),
            ],
            if (e.hazards.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text('Tehlikeler: ${e.hazards.join(", ")}',
                  style: AppTypography.bodySm
                      .copyWith(color: AppColors.error)),
            ],
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }
}

class _MapView extends StatelessWidget {
  const _MapView({
    required this.controller,
    required this.cases,
    required this.route,
    required this.selectedId,
    required this.onMarkerTap,
  });

  final MapController controller;
  final List<EmergencyCase> cases;
  final RouteResult? route;
  final String? selectedId;
  final void Function(EmergencyCase) onMarkerTap;

  @override
  Widget build(BuildContext context) {
    final userLoc =
        context.select<LocationProvider, LatLng?>((p) => p.latLng);
    final center = userLoc ?? const LatLng(41.0082, 28.9784);

    return FlutterMap(
      mapController: controller,
      options: MapOptions(
        initialCenter: center,
        initialZoom: 14,
        minZoom: 5,
        maxZoom: 18,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.klinikNabiz.ilkYardim',
        ),
        if (route != null)
          PolylineLayer(
            polylines: [
              Polyline(
                points: route!.points,
                color: AppColors.primary,
                strokeWidth: 5,
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            if (userLoc != null)
              Marker(
                point: userLoc,
                width: 28,
                height: 28,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.secondary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                ),
              ),
            for (final c in cases) _caseMarker(c),
          ],
        ),
        const _OsmAttribution(),
      ],
    );
  }

  Marker _caseMarker(EmergencyCase c) {
    final color = switch (c.severity) {
      Severity.critical => AppColors.severityCritical,
      Severity.serious => AppColors.severitySerious,
      Severity.minor => AppColors.severityMinor,
    };
    final selected = c.id == selectedId;
    return Marker(
      point: LatLng(c.location.latitude, c.location.longitude),
      width: selected ? 52 : 44,
      height: selected ? 52 : 44,
      child: GestureDetector(
        onTap: () => onMarkerTap(c),
        child: Container(
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.4),
                blurRadius: selected ? 18 : 10,
                spreadRadius: selected ? 4 : 2,
              ),
            ],
            border: Border.all(color: Colors.white, width: 3),
          ),
          child: const Icon(
            Icons.medical_services_rounded,
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }
}

class _OsmAttribution extends StatelessWidget {
  const _OsmAttribution();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: const EdgeInsets.only(
          right: AppSpacing.xs,
          bottom: 90,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xxs,
            vertical: 2,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.8),
            borderRadius: AppSpacing.borderXs,
          ),
          child: const Text(
            '© OpenStreetMap',
            style: TextStyle(fontSize: 9, color: Colors.black54),
          ),
        ),
      ),
    );
  }
}

