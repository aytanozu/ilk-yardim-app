import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../shared/models/post.dart';
import '../data/posts_repo.dart';

class FeedProvider extends ChangeNotifier {
  FeedProvider({PostsRepo? repo}) : _repo = repo ?? PostsRepo() {
    _sub = _repo.watchFeed().listen((p) {
      _posts = p;
      notifyListeners();
      _refreshLikes();
    });
  }

  final PostsRepo _repo;
  StreamSubscription<List<Post>>? _sub;

  List<Post> _posts = [];
  final Set<String> _liked = {};

  List<Post> get posts => _posts;
  bool isLiked(String id) => _liked.contains(id);

  Future<void> _refreshLikes() async {
    final next = <String>{};
    for (final p in _posts) {
      if (await _repo.hasLiked(p.id)) next.add(p.id);
    }
    _liked
      ..clear()
      ..addAll(next);
    notifyListeners();
  }

  Future<void> toggleLike(String postId) async {
    // Optimistic
    if (_liked.contains(postId)) {
      _liked.remove(postId);
    } else {
      _liked.add(postId);
    }
    notifyListeners();
    await _repo.toggleLike(postId);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
