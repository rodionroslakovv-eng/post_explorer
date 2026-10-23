import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:post_explorer/core/error/app_exception.dart';
import 'package:post_explorer/data/local/post_cache.dart';
import 'package:post_explorer/data/models/comment.dart';
import 'package:post_explorer/data/models/create_post_request.dart';
import 'package:post_explorer/data/models/post.dart';
import 'package:post_explorer/data/models/user.dart';
import 'package:post_explorer/data/remote/post_api.dart';

/// Результат создания поста: что ответил сервер и как пост лежит локально.
class CreatePostResult {
  const CreatePostResult({required this.serverPost, required this.localPost});

  /// Объект, который вернул сервер (id всегда 101 — особенность JSONPlaceholder).
  final Post serverPost;

  /// Копия с уникальным локальным id и пометкой isLocal = true.
  final Post localPost;
}

/// Единственная точка доступа UI к данным. UI не знает ни про Dio, ни про Retrofit.
abstract class PostRepository {
  Future<List<Post>> readCachedPosts({int? userId});

  /// Загружает страницу с сервера и обновляет кэш. Бросает только [AppException].
  Future<List<Post>> fetchPosts({
    required int page,
    int limit = 10,
    int? userId,
    CancelToken? cancelToken,
  });

  Future<Post> getPost(int id, {CancelToken? cancelToken});
  Future<List<Comment>> getComments(int postId);

  Future<List<User>> readCachedUsers();
  Future<List<User>> fetchUsers();
  Future<User> getUser(int id);

  Future<CreatePostResult> createPost({
    required String title,
    required String body,
    required int userId,
  });

  Future<List<Post>> readLocalPosts();
}

class PostRepositoryImpl implements PostRepository {
  PostRepositoryImpl({required PostApi api, required PostCache cache})
      : _api = api,
        _cache = cache;

  final PostApi _api;
  final PostCache _cache;

  /// Все сетевые вызовы идут через этот метод: любая ошибка
  /// (Dio, парсинг JSON, неизвестная) превращается в [AppException].
  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (e, s) {
      final exception = AppException.from(e);
      if (kDebugMode && !exception.isCancelled) {
        debugPrint('[Repository] $exception');
      }
      Error.throwWithStackTrace(exception, s);
    }
  }

  // ---------- Посты ----------

  @override
  Future<List<Post>> readCachedPosts({int? userId}) async {
    try {
      return await _cache.readPosts(userId: userId) ?? const <Post>[];
    } catch (e) {
      _logCacheError(e);
      return const <Post>[];
    }
  }

  @override
  Future<List<Post>> fetchPosts({
    required int page,
    int limit = 10,
    int? userId,
    CancelToken? cancelToken,
  }) async {
    final posts = await _guard(
      () => userId == null
          ? _api.getPosts(page, limit, cancelToken: cancelToken)
          : _api.getPostsByUser(userId, page, limit, cancelToken: cancelToken),
    );
    await _updatePostsCache(posts, page: page, userId: userId);
    return posts;
  }

  /// Кэш обновляется только после УСПЕШНОГО ответа. При ошибке
  /// сети предыдущий успешный результат остаётся нетронутым.
  Future<void> _updatePostsCache(
    List<Post> posts, {
    required int page,
    int? userId,
  }) async {
    try {
      if (page <= 1) {
        await _cache.writePosts(posts, userId: userId);
        return;
      }
      final existing = await _cache.readPosts(userId: userId) ?? const <Post>[];
      final known = existing.map((p) => p.id).toSet();
      await _cache.writePosts(
        [...existing, ...posts.where((p) => !known.contains(p.id))],
        userId: userId,
      );
    } catch (e) {
      _logCacheError(e);
    }
  }

  @override
  Future<Post> getPost(int id, {CancelToken? cancelToken}) =>
      _guard(() => _api.getPost(id, cancelToken: cancelToken));

  @override
  Future<List<Comment>> getComments(int postId) =>
      _guard(() => _api.getComments(postId));

  // ---------- Авторы ----------

  @override
  Future<List<User>> readCachedUsers() async {
    try {
      return await _cache.readUsers() ?? const <User>[];
    } catch (e) {
      _logCacheError(e);
      return const <User>[];
    }
  }

  @override
  Future<List<User>> fetchUsers() async {
    final users = await _guard(() => _api.getUsers());
    try {
      await _cache.writeUsers(users);
    } catch (e) {
      _logCacheError(e);
    }
    return users;
  }

  @override
  Future<User> getUser(int id) => _guard(() => _api.getUser(id));

  // ---------- Создание ----------

  @override
  Future<CreatePostResult> createPost({
    required String title,
    required String body,
    required int userId,
  }) async {
    final request = CreatePostRequest(
      title: title.trim(),
      body: body.trim(),
      userId: userId,
    );
    final serverPost = await _guard(() => _api.createPost(request));

    // Сервер всегда отвечает id = 101 и ничего не сохраняет, поэтому для
    // локального списка выдаём уникальный id (101, 102, ...).
    final existing = await readLocalPosts();
    final nextId = existing.fold<int>(100, (m, p) => math.max(m, p.id)) + 1;
    final localPost = serverPost.copyWith(id: nextId, isLocal: true);
    try {
      await _cache.writeLocalPosts([localPost, ...existing]);
    } catch (e) {
      _logCacheError(e);
    }
    return CreatePostResult(serverPost: serverPost, localPost: localPost);
  }

  @override
  Future<List<Post>> readLocalPosts() async {
    try {
      return await _cache.readLocalPosts();
    } catch (e) {
      _logCacheError(e);
      return const <Post>[];
    }
  }

  void _logCacheError(Object e) {
    if (kDebugMode) debugPrint('[Cache] $e');
  }
}
