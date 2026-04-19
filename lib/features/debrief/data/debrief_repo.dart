import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/debrief_entry.dart';

/// Persistence + "pending debrief" bookkeeping. When FCM delivers a
/// `case_closed` to an acceptor we stash the emergencyId locally so the
/// flow survives an app kill / deferred foreground.
class DebriefRepo {
  DebriefRepo({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const _pendingKey = 'pending_debrief_v1';

  Future<void> markPending(String emergencyId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingKey, emergencyId);
  }

  Future<String?> readPending() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_pendingKey);
  }

  Future<void> clearPending() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingKey);
  }

  Future<void> save({
    required String uid,
    required DebriefEntry entry,
  }) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('debriefs')
        .doc(entry.emergencyId)
        .set(entry.toMap(), SetOptions(merge: true));
  }

  Stream<List<DebriefEntry>> watchRecent(String uid, {int max = 20}) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('debriefs')
        .orderBy('createdAt', descending: true)
        .limit(max)
        .snapshots()
        .map((s) => s.docs.map(DebriefEntry.fromSnapshot).toList());
  }
}
