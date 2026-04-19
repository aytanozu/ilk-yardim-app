import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

import 'region.dart';

enum EmergencyType {
  heartAttack('heart_attack', 'Kalp Krizi'),
  breathingDifficulty('breathing_difficulty', 'Nefes Darlığı'),
  choking('choking', 'Boğulma'),
  injury('injury', 'Yaralanma'),
  trafficAccident('traffic_accident', 'Trafik Kazası'),
  poisoning('poisoning', 'Zehirlenme'),
  fall('fall', 'Düşme'),
  unconsciousness('unconsciousness', 'Bilinç Kaybı'),
  other('other', 'Diğer');

  const EmergencyType(this.key, this.turkish);
  final String key;
  final String turkish;

  static EmergencyType fromKey(String? key) => values.firstWhere(
        (e) => e.key == key,
        orElse: () => EmergencyType.other,
      );
}

enum Severity {
  critical('critical', 'Kritik'),
  serious('serious', 'Ciddi'),
  minor('minor', 'Destek');

  const Severity(this.key, this.turkish);
  final String key;
  final String turkish;

  static Severity fromKey(String? key) => values.firstWhere(
        (s) => s.key == key,
        orElse: () => Severity.serious,
      );
}

enum EmergencyStatus {
  open,
  accepted,
  resolved,
  cancelled;

  static EmergencyStatus fromKey(String? key) {
    switch (key) {
      case 'accepted':
        return EmergencyStatus.accepted;
      case 'resolved':
        return EmergencyStatus.resolved;
      case 'cancelled':
        return EmergencyStatus.cancelled;
      case 'open':
      default:
        return EmergencyStatus.open;
    }
  }
}

class EmergencyCase extends Equatable {
  const EmergencyCase({
    required this.id,
    required this.type,
    required this.severity,
    required this.location,
    required this.address,
    required this.description,
    required this.status,
    required this.region,
    required this.createdAt,
    this.geohash,
    this.patient,
    this.contactPhone,
    this.hazards = const [],
    this.acceptedBy,
    this.acceptedAt,
    this.resolvedAt,
    this.waveLevel = 0,
  });

  final String id;
  final EmergencyType type;
  final Severity severity;
  final GeoPoint location;
  final String address;
  final String description;
  final EmergencyStatus status;
  final Region region;
  final DateTime createdAt;
  final String? geohash;
  final PatientInfo? patient;
  final String? contactPhone;
  final List<String> hazards;
  final String? acceptedBy;
  final DateTime? acceptedAt;
  final DateTime? resolvedAt;
  final int waveLevel;

  factory EmergencyCase.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return EmergencyCase(
      id: doc.id,
      type: EmergencyType.fromKey(data['type'] as String?),
      severity: Severity.fromKey(data['severity'] as String?),
      location: (data['location'] as GeoPoint?) ??
          const GeoPoint(41.0082, 28.9784),
      address: data['address'] as String? ?? '',
      description: data['description'] as String? ?? '',
      status: EmergencyStatus.fromKey(data['status'] as String?),
      region: Region.fromMap(
          (data['region'] as Map<String, dynamic>?) ?? const {}),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      geohash: data['geohash'] as String?,
      patient: data['patient'] == null
          ? null
          : PatientInfo.fromMap(
              Map<String, dynamic>.from(data['patient'] as Map)),
      contactPhone: data['contactPhone'] as String?,
      hazards: (data['hazards'] as List?)?.cast<String>() ?? const [],
      acceptedBy: data['acceptedBy'] as String?,
      acceptedAt: (data['acceptedAt'] as Timestamp?)?.toDate(),
      resolvedAt: (data['resolvedAt'] as Timestamp?)?.toDate(),
      waveLevel: (data['waveLevel'] as num?)?.toInt() ?? 0,
    );
  }

  bool get isOpen => status == EmergencyStatus.open;

  @override
  List<Object?> get props => [
        id,
        type,
        severity,
        location,
        address,
        description,
        status,
        region,
        createdAt,
        geohash,
        patient,
        contactPhone,
        hazards,
        acceptedBy,
        acceptedAt,
        resolvedAt,
        waveLevel,
      ];
}

class PatientInfo extends Equatable {
  const PatientInfo({
    this.gender,
    this.age,
    this.consciousness,
    this.breathing,
  });

  final String? gender;
  final int? age;
  final String? consciousness;
  final String? breathing;

  factory PatientInfo.fromMap(Map<String, dynamic> map) => PatientInfo(
        gender: map['gender'] as String?,
        age: (map['age'] as num?)?.toInt(),
        consciousness: map['consciousness'] as String?,
        breathing: map['breathing'] as String?,
      );

  @override
  List<Object?> get props => [gender, age, consciousness, breathing];
}
