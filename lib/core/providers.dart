import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/auth/providers/auth_provider.dart';
import '../features/debrief/data/debrief_repo.dart';
import '../features/emergency/data/emergency_repo.dart';
import '../features/intervention/data/intervention_repo.dart';
import '../features/aed/data/aed_repo.dart';
import 'location/location_provider.dart';

/// Riverpod entry points. We run Riverpod alongside the existing
/// MultiProvider setup so new code can consume either. Over time the
/// `context.read<X>()` callers can be migrated to `ref.watch(xProvider)`
/// file-by-file without a Big-Bang rewrite.

/// Wraps the existing ChangeNotifier-based AuthProvider. Consumers that
/// migrate can `ref.watch(authStateProvider).stage` etc. Note the
/// singleton is still owned by the root MultiProvider; this Riverpod
/// provider is a thin handle.
final authStateProvider =
    ChangeNotifierProvider<AuthProvider>((ref) => AuthProvider());

final locationProvider =
    ChangeNotifierProvider<LocationProvider>((ref) => LocationProvider());

// Plain repo DI — stateless, so simple Provider factories.
final emergencyRepoProvider = Provider<EmergencyRepo>((ref) => EmergencyRepo());
final aedRepoProvider = Provider<AedRepo>((ref) => AedRepo());
final debriefRepoProvider = Provider<DebriefRepo>((ref) => DebriefRepo());
final interventionRepoProvider =
    Provider<InterventionRepo>((ref) => InterventionRepo());
