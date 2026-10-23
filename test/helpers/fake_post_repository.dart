import 'package:dio/dio.dart';
import 'package:post_explorer/core/error/app_exception.dart';
import 'package:post_explorer/data/models/comment.dart';
import 'package:post_explorer/data/models/post.dart';
import 'package:post_explorer/data/models/user.dart';
import 'package:post_explorer/data/repositories/post_repository.dart';

/// 25 постов, по 10 на автора (как в JSONPlaceholder, но короче).
List<Post> buildPosts({int count = 25}) => List<Post>.generate(
      count,
      (i) => Post(
        id: i + 1,
        userId: (i ~/ 10) + 1,
        title: i % 2 == 0 ? 'qui est esse ${i + 1}' : 'eum et est ${i + 1}',
        body: 'body ${i + 1} body ${i + 1}',
      ),
    );

class FetchCall {
  FetchCall(this.page, this.userId);
  final int page;
  final int? userId;
}

/// Управляемый репозиторий для тестов контроллера.
class FakePostRepository implements PostRepository {
  FakePostRepository({List<Post>? all}) : all = all ?? buildPosts();

  final List<Post> all;
  final List<FetchCall> calls = [];

  List<Post> cachedPosts = [];
  List<Post> localPosts = [];

  /// Если задано — fetchPosts бросает это исключение.
  AppException? failWith;

  /// Ошибка только для страниц > 1.
  AppException? failNextPagesWith;

  /// Задержка ответа по userId (для проверки устаревших ответов).
  final Map<int?, Duration> delays = {};
  Duration defaultDelay = const Duration(milliseconds: 10);

  @override
  Future<List<Post>> readCachedPosts({int? userId}) async => cachedPosts;

  @override
  Future<List<Post>> fetchPosts({
    required int page,
    int limit = 10,
    int? userId,
    CancelToken? cancelToken,
  }) async {
    calls.add(FetchCall(page, userId));
    await Future<void>.delayed(delays[userId] ?? defaultDelay);
    if (failWith != null) throw failWith!;
    if (page > 1 && failNextPagesWith != null) throw failNextPagesWith!;
    final source =
        userId == null ? all : all.where((p) => p.userId == userId).toList();
    final start = (page - 1) * limit;
    if (start >= source.length) return const <Post>[];
    final end = start + limit > source.length ? source.length : start + limit;
    return source.sublist(start, end);
  }

  @override
  Future<Post> getPost(int id, {CancelToken? cancelToken}) async =>
      all.firstWhere((p) => p.id == id);

  @override
  Future<List<Comment>> getComments(int postId) async => const <Comment>[];

  @override
  Future<List<User>> readCachedUsers() async => const <User>[];

  @override
  Future<List<User>> fetchUsers() async => const <User>[];

  @override
  Future<User> getUser(int id) async =>
      User(id: id, name: 'User $id', username: 'u$id', email: 'u$id@mail.test');

  @override
  Future<CreatePostResult> createPost({
    required String title,
    required String body,
    required int userId,
  }) async {
    final server = Post(id: 101, userId: userId, title: title, body: body);
    return CreatePostResult(
      serverPost: server,
      localPost: server.copyWith(id: 101, isLocal: true),
    );
  }

  @override
  Future<List<Post>> readLocalPosts() async => localPosts;
}
