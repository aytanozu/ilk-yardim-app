import 'package:cloud_firestore/cloud_firestore.dart';

enum DebriefMood { ok, hard, supportNeeded }

class DebriefEntry {
  const DebriefEntry({
    required this.emergencyId,
    required this.mood,
    this.severity,
    this.wentWell,
    this.wasHard,
    this.nextTime,
    this.selfRating,
    this.createdAt,
  });

  final String emergencyId;
  final DebriefMood mood;
  final String? severity;
  final String? wentWell;
  final String? wasHard;
  final String? nextTime;
  final int? selfRating; // 1..5
  final DateTime? createdAt;

  Map<String, dynamic> toMap() => {
        'emergencyId': emergencyId,
        'mood': _moodKey(mood),
        if (severity != null) 'severity': severity,
        if (wentWell != null && wentWell!.isNotEmpty) 'wentWell': wentWell,
        if (wasHard != null && wasHard!.isNotEmpty) 'wasHard': wasHard,
        if (nextTime != null && nextTime!.isNotEmpty) 'nextTime': nextTime,
        if (selfRating != null) 'selfRating': selfRating,
        'createdAt': FieldValue.serverTimestamp(),
      };

  factory DebriefEntry.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return DebriefEntry(
      emergencyId: (data['emergencyId'] as String?) ?? doc.id,
      mood: _parseMood(data['mood'] as String?),
      severity: data['severity'] as String?,
      wentWell: data['wentWell'] as String?,
      wasHard: data['wasHard'] as String?,
      nextTime: data['nextTime'] as String?,
      selfRating: (data['selfRating'] as num?)?.toInt(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  static String _moodKey(DebriefMood m) => switch (m) {
        DebriefMood.ok => 'ok',
        DebriefMood.hard => 'hard',
        DebriefMood.supportNeeded => 'support_needed',
      };

  static DebriefMood _parseMood(String? k) => switch (k) {
        'hard' => DebriefMood.hard,
        'support_needed' => DebriefMood.supportNeeded,
        _ => DebriefMood.ok,
      };
}
