import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

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
    await _functions
        .httpsCallable('acceptEmergency')
        .call<Map<String, dynamic>>({'emergencyId': emergencyId});
  }
}
