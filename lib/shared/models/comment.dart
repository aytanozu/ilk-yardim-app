import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class Comment extends Equatable {
  const Comment({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.text,
    required this.createdAt,
    this.authorAvatarUrl,
  });

  final String id;
  final String authorId;
  final String authorName;
  final String text;
  final DateTime createdAt;
  final String? authorAvatarUrl;

  factory Comment.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Comment(
      id: doc.id,
      authorId: data['authorId'] as String? ?? '',
      authorName: data['authorName'] as String? ?? '',
      text: data['text'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      authorAvatarUrl: data['authorAvatarUrl'] as String?,
    );
  }

  @override
  List<Object?> get props =>
      [id, authorId, authorName, text, createdAt, authorAvatarUrl];
}
