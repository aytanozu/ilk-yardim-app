import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

import 'region.dart';

class UserStats extends Equatable {
  const UserStats({this.interventions = 0, this.educationPoints = 0});

  final int interventions;
  final int educationPoints;

  factory UserStats.fromMap(Map<String, dynamic>? map) => UserStats(
        interventions: (map?['interventions'] as num?)?.toInt() ?? 0,
        educationPoints: (map?['educationPoints'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toMap() => {
        'interventions': interventions,
        'educationPoints': educationPoints,
      };

  @override
  List<Object?> get props => [interventions, educationPoints];
}

class UserProfile extends Equatable {
  const UserProfile({
    required this.uid,
    required this.phone,
    required this.fullName,
    required this.region,
    this.avatarUrl,
    this.role = 'volunteer',
    this.roleLabel = 'Gönüllü',
    this.stats = const UserStats(),
    this.badges = const [],
    this.fcmTokens = const [],
    this.active = true,
    this.lastLocation,
    this.certificate,
    this.updatedAt,
  });

  final String uid;
  final String phone;
  final String fullName;
  final Region region;
  final String? avatarUrl;
  final String role;
  final String roleLabel;
  final UserStats stats;
  final List<String> badges;
  final List<String> fcmTokens;
  final bool active;
  final GeoPoint? lastLocation;
  final CertificateInfo? certificate;
  final DateTime? updatedAt;

  factory UserProfile.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return UserProfile(
      uid: doc.id,
      phone: data['phone'] as String? ?? '',
      fullName: data['fullName'] as String? ?? '',
      region: Region.fromMap(
          (data['region'] as Map<String, dynamic>?) ?? const {}),
      avatarUrl: data['avatarUrl'] as String?,
      role: data['role'] as String? ?? 'volunteer',
      roleLabel: data['roleLabel'] as String? ?? 'Gönüllü',
      stats: UserStats.fromMap(data['stats'] as Map<String, dynamic>?),
      badges: (data['badges'] as List?)?.cast<String>() ?? const [],
      fcmTokens: (data['fcmTokens'] as List?)?.cast<String>() ?? const [],
      active: data['active'] as bool? ?? true,
      lastLocation: data['lastLocation'] as GeoPoint?,
      certificate: data['certificate'] == null
          ? null
          : CertificateInfo.fromMap(
              Map<String, dynamic>.from(data['certificate'] as Map)),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  @override
  List<Object?> get props => [
        uid,
        phone,
        fullName,
        region,
        avatarUrl,
        role,
        roleLabel,
        stats,
        badges,
        fcmTokens,
        active,
        lastLocation,
        certificate,
        updatedAt,
      ];
}

class CertificateInfo extends Equatable {
  const CertificateInfo({
    required this.type,
    required this.issuer,
    required this.expiresAt,
    this.certificateId,
  });

  final String type;
  final String issuer;
  final DateTime expiresAt;
  final String? certificateId;

  factory CertificateInfo.fromMap(Map<String, dynamic> map) => CertificateInfo(
        type: map['type'] as String? ?? 'İleri İlkyardım Sertifikası',
        issuer: map['issuer'] as String? ?? 'Sağlık Bakanlığı Onaylı',
        expiresAt:
            (map['expiresAt'] as Timestamp?)?.toDate() ?? DateTime(2099),
        certificateId: map['certificateId'] as String?,
      );

  @override
  List<Object?> get props => [type, issuer, expiresAt, certificateId];
}
