import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../../shared/models/quiz_question.dart';

class QuizRepo {
  QuizRepo({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ??
            FirebaseFunctions.instanceFor(region: 'europe-west3');

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

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

  /// Submits a quiz attempt through the `recordQuizAttempt` callable.
  /// Server computes the educationPoints delta and writes both the
  /// attempt and user stats — client no longer touches those paths
  /// directly (Firestore rules forbid it).
  Future<int> saveAttempt({
    required String quizId,
    required Map<String, int> answers,
    required int score,
  }) async {
    final res = await _functions
        .httpsCallable('recordQuizAttempt')
        .call<Map<String, dynamic>>({
      'quizId': quizId,
      'answers': answers,
      'score': score,
    });
    return (res.data['awarded'] as num?)?.toInt() ?? 0;
  }
}
