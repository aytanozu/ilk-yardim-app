import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class Quiz extends Equatable {
  const Quiz({
    required this.id,
    required this.title,
    required this.categoryId,
    required this.questionCount,
  });

  final String id;
  final String title;
  final String categoryId;
  final int questionCount;

  factory Quiz.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Quiz(
      id: doc.id,
      title: data['title'] as String? ?? '',
      categoryId: data['categoryId'] as String? ?? 'basic',
      questionCount: (data['questionCount'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  List<Object?> get props => [id, title, categoryId, questionCount];
}

class QuizQuestion extends Equatable {
  const QuizQuestion({
    required this.id,
    required this.text,
    required this.options,
    required this.correctIndex,
    required this.order,
  });

  final String id;
  final String text;
  final List<String> options;
  final int correctIndex;
  final int order;

  factory QuizQuestion.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return QuizQuestion(
      id: doc.id,
      text: data['text'] as String? ?? '',
      options: (data['options'] as List?)?.cast<String>() ?? const [],
      correctIndex: (data['correctIndex'] as num?)?.toInt() ?? 0,
      order: (data['order'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  List<Object?> get props => [id, text, options, correctIndex, order];
}
