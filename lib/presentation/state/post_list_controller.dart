import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:post_explorer/core/error/app_exception.dart';
import 'package:post_explorer/data/models/post.dart';
import 'package:post_explorer/data/repositories/post_repository.dart';
import 'package:post_explorer/presentation/state/post_list_state.dart';

/// Логика экрана списка: кэш → сеть, пагинация, фильтры, поиск, сортировка.
class PostListController extends ChangeNotifier {
  PostListController(this._repository, {this.pageSize = 10});

  final PostRepository _repository;
  final int pageSize;

  PostListState _state = const PostListState();
  PostListState get state => _state;

  /// Поколение данных. Увеличивается при смене фильтра и обновлении;
  /// ответы «старых» поколений игнорируются, поэтому результаты
  /// разных фильтров не смешиваются.
  int _generation = 0;
  CancelToken? _cancelToken;

  /// Страницы, запрос которых сейчас в полёте (защита от дублей).
  final Set<int> _inFlightPages = <int>{};
  bool _disposed = false;

  void _set(PostListState next) {
    _state = next;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _cancelToken?.cancel('disposed');
    super.dispose();
  }

  // ---------- Загрузка ----------

  /// Первый запуск экрана: локальные посты + кэш, затем сервер.
  Future<void> init() async {
    final locals = await _repository.readLocalPosts();
    _set(_state.copyWith(localPosts: locals));
    await _loadFirstPage(useCache: true, isRefresh: false);
  }

  /// Pull-to-refresh и кнопка «Повторить». Текущие данные остаются на экране.
  Future<void> refresh() =>
      _loadFirstPage(useCache: false, isRefresh: _state.posts.isNotEmpty);

  Future<void> _loadFirstPage({
    required bool useCache,
    required bool isRefresh,
  }) async {
    final gen = ++_generation;
    _cancelToken?.cancel('superseded');
    final token = _cancelToken = CancelToken();
    _inFlightPages.clear();
    final userId = _state.userId;

    List<Post> cached = const <Post>[];
    if (useCache) {
      cached = await _repository.readCachedPosts(userId: userId);
      if (gen != _generation) return;
    }

    if (cached.isNotEmpty) {
      _set(_state.copyWith(
        posts: cached,
        status: ListStatus.cached,
        isRefreshing: true,
        error: null,
        pageStatus: PageStatus.idle,
        pageError: null,
        page: (cached.length / pageSize).ceil(),
        hasMore: true,
      ));
    } else if (isRefresh) {
      _set(_state.copyWith(isRefreshing: true));
    } else {
      _set(_state.copyWith(
        posts: const <Post>[],
        status: ListStatus.loading,
        isRefreshing: false,
        error: null,
        pageStatus: PageStatus.idle,
        pageError: null,
        page: 0,
        hasMore: true,
      ));
    }

    _inFlightPages.add(1);
    try {
      final fresh = await _repository.fetchPosts(
        page: 1,
        limit: pageSize,
        userId: userId,
        cancelToken: token,
      );
      if (gen != _generation) return;
      _set(_state.copyWith(
        posts: fresh,
        status: ListStatus.success,
        isRefreshing: false,
        error: null,
        pageStatus: PageStatus.idle,
        pageError: null,
        page: 1,
        hasMore: fresh.length >= pageSize,
      ));
    } catch (e) {
      final exception = AppException.from(e);
      if (gen != _generation || exception.isCancelled) return;
      if (_state.posts.isNotEmpty) {
        // Последний успешный результат не удаляем — показываем его как кэш.
        _set(_state.copyWith(
          status: ListStatus.cached,
          isRefreshing: false,
          error: exception,
        ));
      } else {
        _set(_state.copyWith(
          status: ListStatus.error,
          isRefreshing: false,
          error: exception,
        ));
      }
    } finally {
      if (gen == _generation) _inFlightPages.remove(1);
    }
  }

  // ---------- Пагинация ----------

  /// Подгрузка следующей страницы. Безопасно вызывать сколько угодно раз
  /// подряд: одна и та же страница не запрашивается дважды.
  Future<void> loadNextPage() async {
    final s = _state;
    if (!s.hasMore) return;
    if (s.isRefreshing) return;
    if (s.status == ListStatus.loading || s.status == ListStatus.error) return;
    if (s.pageStatus == PageStatus.loading) return;
    // После ошибки страница грузится только по кнопке «Повторить».
    if (s.pageStatus == PageStatus.error) return;

    final next = s.page + 1;
    if (_inFlightPages.contains(next)) return;
    await _loadPage(next);
  }

  /// Кнопка «Повторить» под списком.
  Future<void> retryNextPage() async {
    _set(_state.copyWith(pageStatus: PageStatus.idle, pageError: null));
    await loadNextPage();
  }

  Future<void> _loadPage(int pageNumber) async {
    final gen = _generation;
    final token = _cancelToken;
    final userId = _state.userId;

    _inFlightPages.add(pageNumber);
    _set(_state.copyWith(pageStatus: PageStatus.loading, pageError: null));
    try {
      final items = await _repository.fetchPosts(
        page: pageNumber,
        limit: pageSize,
        userId: userId,
        cancelToken: token,
      );
      if (gen != _generation) return;
      final known = _state.posts.map((p) => p.id).toSet();
      final merged = <Post>[
        ..._state.posts,
        ...items.where((p) => !known.contains(p.id)),
      ];
      _set(_state.copyWith(
        posts: merged,
        page: pageNumber,
        hasMore: items.length >= pageSize,
        pageStatus: PageStatus.idle,
      ));
    } catch (e) {
      final exception = AppException.from(e);
      if (gen != _generation || exception.isCancelled) return;
      _set(_state.copyWith(
        pageStatus: PageStatus.error,
        pageError: exception,
      ));
    } finally {
      if (gen == _generation) _inFlightPages.remove(pageNumber);
    }
  }

  // ---------- Фильтры, поиск, сортировка ----------

  /// Смена автора: страницы и результаты сбрасываются, старый запрос отменяется.
  Future<void> setUserFilter(int? userId) async {
    if (userId == _state.userId) return;
    _set(_state.copyWith(
      userId: userId,
      posts: const <Post>[],
      status: ListStatus.loading,
      pageStatus: PageStatus.idle,
      error: null,
      pageError: null,
      page: 0,
      hasMore: true,
      isRefreshing: false,
    ));
    await _loadFirstPage(useCache: true, isRefresh: false);
  }

  /// Поиск локальный — по уже загруженным постам.
  void setQuery(String query) => _set(_state.copyWith(query: query));

  void toggleSort() =>
      _set(_state.copyWith(sortAscending: !_state.sortAscending));

  Future<void> resetFilters() async {
    _set(_state.copyWith(query: '', sortAscending: true));
    if (_state.userId != null) {
      await setUserFilter(null);
    }
  }

  // ---------- Локальные посты ----------

  void addLocalPost(Post post) {
    _set(_state.copyWith(localPosts: [post, ..._state.localPosts]));
  }
}
