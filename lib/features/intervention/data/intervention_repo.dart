import 'package:cloud_functions/cloud_functions.dart';

import '../models/intervention_report.dart';

class InterventionRepo {
  InterventionRepo({FirebaseFunctions? functions})
      : _functions = functions ??
            FirebaseFunctions.instanceFor(region: 'europe-west3');

  final FirebaseFunctions _functions;

  Future<void> submit(InterventionReport report) async {
    await _functions
        .httpsCallable('recordIntervention')
        .call<Map<String, dynamic>>(report.toCallablePayload());
  }
}
