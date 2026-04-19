import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../shared/models/training_item.dart';

class TrainingRepo {
  TrainingRepo({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<TrainingItem?> featured() async {
    final snap = await _firestore
        .collection('training_items')
        .where('featured', isEqualTo: true)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return TrainingItem.fromSnapshot(snap.docs.first);
  }

  Stream<List<TrainingItem>> watchPopular({int limit = 10}) {
    return _firestore
        .collection('training_items')
        .orderBy('viewCount', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map(TrainingItem.fromSnapshot).toList());
  }

  Future<List<TrainingItem>> byCategory(TrainingCategory category) async {
    final snap = await _firestore
        .collection('training_items')
        .where('category', isEqualTo: category.key)
        .orderBy('viewCount', descending: true)
        .get();
    return snap.docs.map(TrainingItem.fromSnapshot).toList();
  }
}
