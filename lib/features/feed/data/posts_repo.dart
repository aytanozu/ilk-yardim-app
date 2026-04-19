import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../shared/models/comment.dart';
import '../../../shared/models/post.dart';

class PostsRepo {
  PostsRepo({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<List<Post>> watchFeed({int limit = 30}) {
    return _firestore
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map(Post.fromSnapshot).toList());
  }

  Future<void> toggleLike(String postId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final likeRef = _firestore
        .collection('posts')
        .doc(postId)
        .collection('likes')
        .doc(uid);

    await _firestore.runTransaction((tx) async {
      final likeSnap = await tx.get(likeRef);
      final postRef = _firestore.collection('posts').doc(postId);
      if (likeSnap.exists) {
        tx.delete(likeRef);
        tx.update(postRef, {'likeCount': FieldValue.increment(-1)});
      } else {
        tx.set(likeRef, {'createdAt': FieldValue.serverTimestamp()});
        tx.update(postRef, {'likeCount': FieldValue.increment(1)});
      }
    });
  }

  Future<bool> hasLiked(String postId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;
    final s = await _firestore
        .collection('posts')
        .doc(postId)
        .collection('likes')
        .doc(uid)
        .get();
    return s.exists;
  }

  Future<void> createPost({
    required String authorId,
    required String authorName,
    String? authorAvatarUrl,
    required String text,
    String? imageUrl,
    String? location,
  }) async {
    await _firestore.collection('posts').add({
      'authorId': authorId,
      'authorName': authorName,
      'authorAvatarUrl': authorAvatarUrl,
      'text': text,
      'imageUrl': imageUrl,
      'location': location,
      'likeCount': 0,
      'commentCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<Comment>> watchComments(String postId, {int limit = 100}) {
    return _firestore
        .collection('posts')
        .doc(postId)
        .collection('comments')
        .orderBy('createdAt', descending: false)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map(Comment.fromSnapshot).toList());
  }

  Future<void> addComment({
    required String postId,
    required String authorId,
    required String authorName,
    String? authorAvatarUrl,
    required String text,
  }) async {
    final postRef = _firestore.collection('posts').doc(postId);
    final commentRef = postRef.collection('comments').doc();
    await _firestore.runTransaction((tx) async {
      tx.set(commentRef, {
        'authorId': authorId,
        'authorName': authorName,
        'authorAvatarUrl': authorAvatarUrl,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
      });
      tx.update(postRef, {
        'commentCount': FieldValue.increment(1),
      });
    });
  }
}
