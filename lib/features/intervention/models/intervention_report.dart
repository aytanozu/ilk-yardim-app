import 'package:cloud_firestore/cloud_firestore.dart';

enum PatientCondition { stable, critical, unconscious, recovering, deceased }

class InterventionReport {
  const InterventionReport({
    required this.emergencyId,
    required this.uid,
    required this.condition,
    required this.actions,
    this.notes,
    this.createdAt,
  });

  final String emergencyId;
  final String uid;
  final PatientCondition condition;
  final Set<String> actions; // 'cpr', 'aed', 'bleeding', 'fracture', 'positioning'
  final String? notes;
  final DateTime? createdAt;

  Map<String, dynamic> toCallablePayload() => {
        'emergencyId': emergencyId,
        'condition': _conditionKey(condition),
        'actions': actions.toList(),
        'notes': notes ?? '',
      };

  static String _conditionKey(PatientCondition c) => switch (c) {
        PatientCondition.stable => 'stable',
        PatientCondition.critical => 'critical',
        PatientCondition.unconscious => 'unconscious',
        PatientCondition.recovering => 'recovering',
        PatientCondition.deceased => 'deceased',
      };

  static PatientCondition conditionFromKey(String? k) => switch (k) {
        'critical' => PatientCondition.critical,
        'unconscious' => PatientCondition.unconscious,
        'recovering' => PatientCondition.recovering,
        'deceased' => PatientCondition.deceased,
        _ => PatientCondition.stable,
      };

  factory InterventionReport.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return InterventionReport(
      emergencyId: (data['emergencyId'] as String?) ?? '',
      uid: (data['uid'] as String?) ?? '',
      condition: conditionFromKey(data['condition'] as String?),
      actions:
          ((data['actions'] as List?)?.cast<String>() ?? const []).toSet(),
      notes: data['notes'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

/// User-facing Turkish labels for the patient-condition radio.
const Map<PatientCondition, String> kConditionLabels = {
  PatientCondition.stable: 'Stabil',
  PatientCondition.critical: 'Kritik',
  PatientCondition.unconscious: 'Bilinçsiz',
  PatientCondition.recovering: 'İyileşiyor',
  PatientCondition.deceased: 'Vefat',
};

/// Action checkbox labels.
const List<(String, String)> kActionOptions = [
  ('cpr', 'Kalp masajı (CPR)'),
  ('aed', 'AED kullanıldı'),
  ('bleeding', 'Kanama kontrolü'),
  ('fracture', 'Kırık stabilizasyonu'),
  ('positioning', 'Pozisyon verme'),
];
