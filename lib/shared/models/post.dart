import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class Post extends Equatable {
  const Post({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.text,
    required this.createdAt,
    this.authorAvatarUrl,
    this.imageUrl,
    this.location,
    this.likeCount = 0,
    this.commentCount = 0,
  });

  final String id;
  final String authorId;
  final String authorName;
  final String text;
  final DateTime createdAt;
  final String? authorAvatarUrl;
  final String? imageUrl;
  final String? location;
  final int likeCount;
  final int commentCount;

  factory Post.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Post(
      id: doc.id,
      authorId: data['authorId'] as String? ?? '',
      authorName: data['authorName'] as String? ?? '',
      text: data['text'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      authorAvatarUrl: data['authorAvatarUrl'] as String?,
      imageUrl: data['imageUrl'] as String?,
      location: data['location'] as String?,
      likeCount: (data['likeCount'] as num?)?.toInt() ?? 0,
      commentCount: (data['commentCount'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  List<Object?> get props => [
        id,
        authorId,
        authorName,
        text,
        createdAt,
        authorAvatarUrl,
        imageUrl,
        location,
        likeCount,
        commentCount,
      ];
}
