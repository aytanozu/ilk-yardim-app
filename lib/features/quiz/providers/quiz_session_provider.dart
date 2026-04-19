import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../../shared/models/quiz_question.dart';
import '../data/quiz_repo.dart';

class QuizSessionProvider extends ChangeNotifier {
  QuizSessionProvider({QuizRepo? repo, required this.quizId})
      : _repo = repo ?? QuizRepo();

  final QuizRepo _repo;
  final String quizId;

  Quiz? _quiz;
  List<QuizQuestion> _questions = [];
  int _index = 0;
  int? _selectedOption;
  final Map<String, int> _answers = {};
  bool _loading = true;
  bool _completed = false;
  int _score = 0;

  Quiz? get quiz => _quiz;
  List<QuizQuestion> get questions => _questions;
  int get index => _index;
  int? get selectedOption => _selectedOption;
  bool get loading => _loading;
  bool get completed => _completed;
  int get score => _score;

  QuizQuestion? get current =>
      _questions.isEmpty ? null : _questions[_index];

  double get progress =>
      _questions.isEmpty ? 0 : (_index + 1) / _questions.length;

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    _quiz = await _repo.loadQuiz(quizId);
    _questions = await _repo.loadQuestions(quizId);
    _loading = false;
    notifyListeners();
  }

  void select(int option) {
    _selectedOption = option;
    notifyListeners();
  }

  Future<void> next() async {
    if (_selectedOption == null || current == null) return;
    _answers[current!.id] = _selectedOption!;
    if (_selectedOption == current!.correctIndex) _score++;

    if (_index < _questions.length - 1) {
      _index++;
      _selectedOption = null;
      notifyListeners();
    } else {
      await _finish();
    }
  }

  Future<void> _finish() async {
    _completed = true;
    notifyListeners();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await _repo.saveAttempt(
        quizId: quizId,
        answers: _answers,
        score: _score,
      );
    } catch (_) {
      // Best-effort: callable failure shouldn't block the result screen.
    }
  }
}
