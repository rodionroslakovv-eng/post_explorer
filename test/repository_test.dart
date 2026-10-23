import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:post_explorer/core/error/app_exception.dart';
import 'package:post_explorer/data/models/post.dart';
import 'package:post_explorer/data/remote/post_api.dart';
import 'package:post_explorer/data/repositories/post_repository.dart';

import 'helpers/in_memory_cache.dart';
import 'helpers/mock_adapter.dart';

void main() {
  late MockAdapter adapter;
  late InMemoryPostCache cache;
  late PostRepositoryImpl repository;

  void setUpRepository(MockHandler handler) {
    adapter = MockAdapter(handler);
    cache = InMemoryPostCache();
    repository = PostRepositoryImpl(
      api: PostApi(MockAdapter.dioWith(adapter)),
      cache: cache,
    );
  }

  final postsJson = [
    {'userId': 1, 'id': 1, 'title': 'first', 'body': 'body one'},
    {'userId': 1, 'id': 2, 'title': 'second', 'body': 'body two'},
  ];

  group('Загрузка постов', () {
    test('3. успешная загрузка постов через репозиторий', () async {
      setUpRepository((_) async => MockAdapter.json(postsJson));

      final posts = await repository.fetchPosts(page: 1, limit: 10);

      expect(posts.map((p) => p.id), [1, 2]);

      final request = adapter.requests.single;
      expect(request.method, 'GET');
      expect(request.path, '/posts');
      expect(request.queryParameters, containsPair('_page', 1));
      expect(request.queryParameters, containsPair('_limit', 10));
      // технические заголовки добавляет ApiInterceptor
      expect(request.headers['X-Client-Name'], 'post_explorer');
      expect(request.headers['X-Request-Id'], isNotNull);

      // кэш обновлён после успешного ответа
      expect(cache.posts[null]!.length, 2);
    });

    test('посты автора запрашиваются с userId', () async {
      setUpRepository((_) async => MockAdapter.json(postsJson));

      await repository.fetchPosts(page: 1, limit: 10, userId: 1);

      expect(adapter.requests.single.queryParameters, containsPair('userId', 1));
      expect(cache.posts[1], isNotNull);
    });

    test('вторая страница дописывается в кэш без дублей', () async {
      setUpRepository((o) async {
        if (o.queryParameters['_page'] == 1) return MockAdapter.json(postsJson);
        return MockAdapter.json([
          postsJson.last,
          {'userId': 1, 'id': 3, 'title': 'third', 'body': 'body three'},
        ]);
      });

      await repository.fetchPosts(page: 1);
      await repository.fetchPosts(page: 2);

      expect(cache.posts[null]!.map((p) => p.id), [1, 2, 3]);
    });

    test('4. ошибка сервера (500) -> AppException(server), кэш не тронут', () async {
      setUpRepository((_) async => MockAdapter.json({}, status: 500));
      cache.posts[null] = [
        const Post(id: 1, userId: 1, title: 'cached', body: 'cached body'),
      ];

      await expectLater(
        repository.fetchPosts(page: 1),
        throwsA(
          isA<AppException>()
              .having((e) => e.type, 'type', AppErrorType.server)
              .having((e) => e.statusCode, 'statusCode', 500),
        ),
      );

      expect(cache.posts[null]!.single.title, 'cached');
      expect((await repository.readCachedPosts()).length, 1);
    });

    test('404 -> AppException(client)', () async {
      setUpRepository((_) async => MockAdapter.json({}, status: 404));

      await expectLater(
        repository.getPost(999),
        throwsA(isA<AppException>().having((e) => e.type, 'type', AppErrorType.client)),
      );
    });

    test('таймаут -> AppException(timeout)', () async {
      setUpRepository((o) async => throw DioException(
            requestOptions: o,
            type: DioExceptionType.connectionTimeout,
          ));

      await expectLater(
        repository.fetchPosts(page: 1),
        throwsA(isA<AppException>().having((e) => e.type, 'type', AppErrorType.timeout)),
      );
    });

    test('нет сети -> AppException(noConnection)', () async {
      setUpRepository((o) async => throw DioException(
            requestOptions: o,
            type: DioExceptionType.connectionError,
          ));

      await expectLater(
        repository.fetchPosts(page: 1),
        throwsA(
          isA<AppException>().having((e) => e.type, 'type', AppErrorType.noConnection),
        ),
      );
    });

    test('некорректный JSON не роняет приложение -> AppException(parse)', () async {
      setUpRepository((_) async => MockAdapter.json([
            {'id': 1}, // нет userId/title/body
          ]));

      await expectLater(
        repository.fetchPosts(page: 1),
        throwsA(isA<AppException>().having((e) => e.type, 'type', AppErrorType.parse)),
      );
    });
  });

  group('Комментарии и авторы', () {
    test('getComments возвращает список комментариев', () async {
      setUpRepository((_) async => MockAdapter.json([
            {'postId': 1, 'id': 1, 'name': 'n', 'email': 'e@e.e', 'body': 'b'},
          ]));

      final comments = await repository.getComments(1);

      expect(adapter.requests.single.path, '/posts/1/comments');
      expect(comments.single.email, 'e@e.e');
    });

    test('fetchUsers сохраняет авторов в кэш', () async {
      setUpRepository((_) async => MockAdapter.json([
            {'id': 1, 'name': 'A', 'username': 'a', 'email': 'a@a.a'},
          ]));

      final users = await repository.fetchUsers();

      expect(users.single.name, 'A');
      expect((await repository.readCachedUsers()).single.id, 1);
    });
  });

  group('POST /posts (mock-адаптер Dio)', () {
    test('отправляет тело, возвращает объект сервера и локальную копию', () async {
      setUpRepository((o) async {
        expect(o.method, 'POST');
        expect(o.path, '/posts');
        expect(o.data, {'title': 'Hello world', 'body': 'Some long body', 'userId': 3});
        return MockAdapter.json(
          {'id': 101, 'title': 'Hello world', 'body': 'Some long body', 'userId': 3},
          status: 201,
        );
      });

      final first = await repository.createPost(
        title: '  Hello world ',
        body: 'Some long body',
        userId: 3,
      );

      expect(first.serverPost.id, 101);
      expect(first.localPost.isLocal, isTrue);
      expect(first.localPost.id, 101);

      final second = await repository.createPost(
        title: 'Hello world',
        body: 'Some long body',
        userId: 3,
      );
      // сервер снова вернул 101, локальный id уникален
      expect(second.serverPost.id, 101);
      expect(second.localPost.id, 102);
      expect((await repository.readLocalPosts()).length, 2);
    });

    test('ошибка POST -> AppException, локальный список не меняется', () async {
      setUpRepository((_) async => MockAdapter.json({}, status: 500));

      await expectLater(
        repository.createPost(title: 'Hello world', body: 'Some long body', userId: 1),
        throwsA(isA<AppException>().having((e) => e.type, 'type', AppErrorType.server)),
      );
      expect(await repository.readLocalPosts(), isEmpty);
    });
  });
}
