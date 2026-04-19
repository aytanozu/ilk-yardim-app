import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../../core/observability/breadcrumbs.dart';
import '../../../shared/models/emergency_case.dart';

class EmergencyRepo {
  EmergencyRepo({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ??
            FirebaseFunctions.instanceFor(region: 'europe-west3');

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  Stream<List<EmergencyCase>> watchOpenCasesForCity(String city) {
    return _firestore
        .collection('emergencies')
        .where('region.city', isEqualTo: city)
        .where('status', whereIn: ['open', 'accepted'])
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((s) => s.docs.map(EmergencyCase.fromSnapshot).toList());
  }

  Stream<EmergencyCase?> watchCase(String id) {
    return _firestore
        .collection('emergencies')
        .doc(id)
        .snapshots()
        .map((s) => s.exists ? EmergencyCase.fromSnapshot(s) : null);
  }

  Future<void> accept(String emergencyId) async {
    breadcrumb('accept_call_start', {'emergencyId': emergencyId});
    try {
      await _functions
          .httpsCallable('acceptEmergency')
          .call<Map<String, dynamic>>({'emergencyId': emergencyId});
      breadcrumb('accept_call_ok', {'emergencyId': emergencyId});
    } catch (e) {
      breadcrumb('accept_call_fail',
          {'emergencyId': emergencyId, 'err': e.toString()});
      rethrow;
    }
  }

  /// Idempotent arrival signal — backend stamps `arrivedAt` only the
  /// first time any acceptor fires this for a given case.
  Future<void> markArrived(String emergencyId) async {
    breadcrumb('mark_arrived', {'emergencyId': emergencyId});
    await _functions
        .httpsCallable('markArrived')
        .call<Map<String, dynamic>>({'emergencyId': emergencyId});
  }
}
