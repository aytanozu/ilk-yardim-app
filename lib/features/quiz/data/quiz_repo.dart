import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../shared/models/quiz_question.dart';

class QuizRepo {
  QuizRepo({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<Quiz?> loadQuiz(String id) async {
    final doc = await _firestore.collection('quizzes').doc(id).get();
    if (!doc.exists) return null;
    return Quiz.fromSnapshot(doc);
  }

  Future<List<QuizQuestion>> loadQuestions(String quizId) async {
    final snap = await _firestore
        .collection('quizzes')
        .doc(quizId)
        .collection('questions')
        .orderBy('order')
        .get();
    return snap.docs.map(QuizQuestion.fromSnapshot).toList();
  }

  Future<void> saveAttempt({
    required String uid,
    required String quizId,
    required Map<String, int> answers,
    required int score,
  }) async {
    await _firestore.collection('quiz_attempts').doc('${uid}_$quizId').set({
      'uid': uid,
      'quizId': quizId,
      'answers': answers,
      'score': score,
      'completedAt': FieldValue.serverTimestamp(),
    });
    // Bonus points to user.stats.educationPoints
    await _firestore.collection('users').doc(uid).set({
      'stats': {'educationPoints': FieldValue.increment(score * 10)},
    }, SetOptions(merge: true));
  }
}
