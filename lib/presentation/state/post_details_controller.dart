import 'package:flutter/foundation.dart';
import 'package:post_explorer/core/error/app_exception.dart';
import 'package:post_explorer/data/models/comment.dart';
import 'package:post_explorer/data/models/post.dart';
import 'package:post_explorer/data/models/user.dart';
import 'package:post_explorer/data/repositories/post_repository.dart';
import 'package:post_explorer/presentation/state/async_value.dart';

/// Экран деталей: пост, автор и комментарии грузятся независимо,
/// у каждой части свои Loading / Success / Error.
class PostDetailsController extends ChangeNotifier {
  PostDetailsController(this._repository, this.initialPost)
      : _post = AsyncValue<Post>.success(initialPost);

  final PostRepository _repository;
  final Post initialPost;

  AsyncValue<Post> _post;
  AsyncValue<List<Comment>> _comments = const AsyncValue.loading();
  AsyncValue<User> _author = const AsyncValue.loading();
  bool _disposed = false;

  AsyncValue<Post> get post => _post;
  AsyncValue<List<Comment>> get comments => _comments;
  AsyncValue<User> get author => _author;

  /// Локальный пост не существует на сервере — запросы за ним бессмысленны.
  bool get isLocal => initialPost.isLocal;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> load() async {
    await Future.wait<void>([
      loadPost(),
      loadComments(),
      loadAuthor(),
    ]);
  }

  Future<void> loadPost() async {
    if (isLocal) return;
    _post = AsyncValue<Post>.loading(_post.data);
    _notify();
    try {
      final fresh = await _repository.getPost(initialPost.id);
      _post = AsyncValue<Post>.success(fresh);
    } catch (e) {
      // Остаются данные из списка, ошибка показывается рядом.
      _post = AsyncValue<Post>.failure(AppException.from(e), _post.data);
    }
    _notify();
  }

  Future<void> loadComments() async {
    if (isLocal) {
      _comments = const AsyncValue<List<Comment>>.success(<Comment>[]);
      _notify();
      return;
    }
    _comments = AsyncValue<List<Comment>>.loading(_comments.data);
    _notify();
    try {
      final items = await _repository.getComments(initialPost.id);
      _comments = AsyncValue<List<Comment>>.success(items);
    } catch (e) {
      _comments =
          AsyncValue<List<Comment>>.failure(AppException.from(e), _comments.data);
    }
    _notify();
  }

  Future<void> loadAuthor() async {
    _author = AsyncValue<User>.loading(_author.data);
    _notify();
    try {
      final user = await _repository.getUser(initialPost.userId);
      _author = AsyncValue<User>.success(user);
    } catch (e) {
      _author = AsyncValue<User>.failure(AppException.from(e), _author.data);
    }
    _notify();
  }
}
