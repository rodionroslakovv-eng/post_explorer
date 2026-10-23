import 'package:flutter_test/flutter_test.dart';
import 'package:post_explorer/core/error/app_exception.dart';
import 'package:post_explorer/data/models/post.dart';
import 'package:post_explorer/presentation/state/post_list_controller.dart';
import 'package:post_explorer/presentation/state/post_list_state.dart';

import 'helpers/fake_post_repository.dart';

const _offline = AppException(
  type: AppErrorType.noConnection,
  message: 'Нет подключения к интернету.',
);

Future<PostListController> startedController(FakePostRepository repo) async {
  final controller = PostListController(repo);
  await controller.init();
  return controller;
}

void main() {
  group('Загрузка и пагинация', () {
    test('первичная загрузка — 10 постов', () async {
      final repo = FakePostRepository();
      final c = await startedController(repo);

      expect(c.state.status, ListStatus.success);
      expect(c.state.posts.length, 10);
      expect(c.state.page, 1);
      expect(c.state.hasMore, isTrue);
    });

    test('подгрузка добавляет страницы без дублей', () async {
      final repo = FakePostRepository();
      final c = await startedController(repo);

      await c.loadNextPage();
      await c.loadNextPage();

      final ids = c.state.posts.map((p) => p.id).toList();
      expect(ids.length, 25);
      expect(ids.toSet().length, 25);
      expect(c.state.hasMore, isFalse); // последняя страница неполная
    });

    test('6. защита от дублирующейся загрузки одной страницы', () async {
      final repo = FakePostRepository();
      final c = await startedController(repo);

      // три вызова подряд, пока первый запрос ещё в полёте
      final futures = [
        c.loadNextPage(),
        c.loadNextPage(),
        c.loadNextPage(),
      ];
      await Future.wait(futures);

      final page2Calls = repo.calls.where((call) => call.page == 2).length;
      expect(page2Calls, 1);
      expect(c.state.posts.length, 20);
    });

    test('сервер вернул пересекающиеся id — дубли не появляются', () async {
      final repo = FakePostRepository(all: buildPosts(count: 25));
      final c = await startedController(repo);
      // подмешиваем уже существующий пост в «вторую страницу»
      repo.all[10] = repo.all[0];

      await c.loadNextPage();

      final ids = c.state.posts.map((p) => p.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('ошибка следующей страницы: данные остаются, повтор по кнопке', () async {
      final repo = FakePostRepository()..failNextPagesWith = _offline;
      final c = await startedController(repo);

      await c.loadNextPage();
      expect(c.state.pageStatus, PageStatus.error);
      expect(c.state.posts.length, 10);

      // автоподгрузка при ошибке не зацикливается
      final callsAfterError = repo.calls.length;
      await c.loadNextPage();
      expect(repo.calls.length, callsAfterError);

      repo.failNextPagesWith = null;
      await c.retryNextPage();
      expect(c.state.pageStatus, PageStatus.idle);
      expect(c.state.posts.length, 20);
    });
  });

  group('Фильтры', () {
    test('5. фильтрация по автору: старые результаты не смешиваются', () async {
      final repo = FakePostRepository();
      final c = await startedController(repo);
      expect(c.state.posts.any((p) => p.userId == 1), isTrue);

      await c.setUserFilter(2);

      expect(c.state.userId, 2);
      expect(c.state.page, 1);
      expect(c.state.posts, isNotEmpty);
      expect(c.state.posts.every((p) => p.userId == 2), isTrue);
    });

    test('устаревший ответ при быстрой смене фильтра игнорируется', () async {
      final repo = FakePostRepository()
        ..delays[1] = const Duration(milliseconds: 60)
        ..delays[2] = const Duration(milliseconds: 5);
      final c = PostListController(repo);

      final first = c.setUserFilter(1);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      final second = c.setUserFilter(2);
      await Future.wait([first, second]);
      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(repo.calls.any((call) => call.userId == 1), isTrue);
      expect(c.state.posts.every((p) => p.userId == 2), isTrue);
    });

    test('5. поиск по заголовку (локальный, без учёта регистра)', () async {
      final repo = FakePostRepository();
      final c = await startedController(repo);
      final callsBefore = repo.calls.length;

      c.setQuery('QUI EST');

      final visible = c.state.visiblePosts;
      expect(visible, isNotEmpty);
      expect(visible.every((p) => p.title.toLowerCase().contains('qui est')), isTrue);
      expect(repo.calls.length, callsBefore); // сервер не вызывался
    });

    test('сортировка по ID и сброс фильтров', () async {
      final repo = FakePostRepository();
      final c = await startedController(repo);

      c.toggleSort();
      expect(c.state.visiblePosts.first.id, 10);

      c.setQuery('zzz');
      expect(c.state.visiblePosts, isEmpty);

      await c.setUserFilter(1);
      await c.resetFilters();
      expect(c.state.userId, isNull);
      expect(c.state.query, isEmpty);
      expect(c.state.sortAscending, isTrue);
      expect(c.state.hasActiveFilters, isFalse);
    });
  });

  group('Кэш и ошибки', () {
    test('сначала кэш, затем свежие данные с сервера', () async {
      final repo = FakePostRepository()
        ..cachedPosts = [buildPosts().first]
        ..defaultDelay = const Duration(milliseconds: 30);
      final c = PostListController(repo);

      final loading = c.init();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(c.state.status, ListStatus.cached);
      expect(c.state.posts.length, 1);
      expect(c.state.isRefreshing, isTrue);

      await loading;
      expect(c.state.status, ListStatus.success);
      expect(c.state.posts.length, 10);
    });

    test('нет сети, кэш есть: показываем кэш и не стираем его', () async {
      final repo = FakePostRepository()
        ..cachedPosts = buildPosts().take(3).toList()
        ..failWith = _offline;
      final c = await startedController(repo);

      expect(c.state.status, ListStatus.cached);
      expect(c.state.posts.length, 3);
      expect(c.state.error?.type, AppErrorType.noConnection);
      expect(c.state.isRefreshing, isFalse);
    });

    test('нет сети и нет кэша: состояние error, потом успешный повтор', () async {
      final repo = FakePostRepository()..failWith = _offline;
      final c = await startedController(repo);

      expect(c.state.status, ListStatus.error);
      expect(c.state.posts, isEmpty);

      repo.failWith = null;
      await c.refresh();
      expect(c.state.status, ListStatus.success);
      expect(c.state.posts.length, 10);
    });

    test('ошибка pull-to-refresh не удаляет уже показанные данные', () async {
      final repo = FakePostRepository();
      final c = await startedController(repo);

      repo.failWith = _offline;
      await c.refresh();

      expect(c.state.status, ListStatus.cached);
      expect(c.state.posts.length, 10);
    });
  });

  group('Локальные посты', () {
    test('созданные локально посты показываются сверху с пометкой', () async {
      final repo = FakePostRepository()
        ..localPosts = [
          const Post(id: 101, userId: 1, title: 'mine', body: 'my body text', isLocal: true),
        ];
      final c = await startedController(repo);

      expect(c.state.visiblePosts.first.isLocal, isTrue);

      await c.setUserFilter(2);
      expect(c.state.visiblePosts.any((p) => p.isLocal), isFalse);
    });

    test('addLocalPost добавляет пост в список', () async {
      final repo = FakePostRepository();
      final c = await startedController(repo);

      c.addLocalPost(
        const Post(id: 101, userId: 1, title: 'new', body: 'new body text', isLocal: true),
      );

      expect(c.state.visiblePosts.first.title, 'new');
    });
  });
}
