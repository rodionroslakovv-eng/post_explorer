import 'package:post_explorer/core/error/app_exception.dart';
import 'package:post_explorer/data/models/post.dart';

/// Состояние экрана списка (раздел 5 задания).
enum ListStatus {
  /// Первичная загрузка, данных ещё нет.
  loading,

  /// Свежие данные с сервера.
  success,

  /// Показаны сохранённые данные: идёт обновление или сервер недоступен.
  cached,

  /// Данных нет и загрузить не удалось.
  error,
}

/// Подгрузка следующей страницы — отдельное состояние, не смешивается
/// с первичной загрузкой и отправкой формы.
enum PageStatus { idle, loading, error }

const Object _unset = Object();

class PostListState {
  const PostListState({
    this.status = ListStatus.loading,
    this.posts = const <Post>[],
    this.localPosts = const <Post>[],
    this.pageStatus = PageStatus.idle,
    this.error,
    this.pageError,
    this.userId,
    this.query = '',
    this.sortAscending = true,
    this.page = 0,
    this.hasMore = true,
    this.isRefreshing = false,
  });

  final ListStatus status;

  /// Посты, загруженные с сервера (или из кэша) для текущего фильтра.
  final List<Post> posts;

  /// Посты, созданные локально.
  final List<Post> localPosts;

  final PageStatus pageStatus;
  final AppException? error;
  final AppException? pageError;

  /// Фильтр по автору (null — все авторы).
  final int? userId;

  /// Поисковая строка (поиск локальный — по загруженным постам).
  final String query;
  final bool sortAscending;

  /// Номер последней загруженной страницы.
  final int page;
  final bool hasMore;
  final bool isRefreshing;

  bool get hasActiveFilters =>
      userId != null || query.trim().isNotEmpty || !sortAscending;

  /// Список для отображения: локальные посты сверху, затем серверные,
  /// отсортированные по id. Поиск — по заголовку среди загруженных постов.
  List<Post> get visiblePosts {
    final q = query.trim().toLowerCase();
    bool matches(Post p) => q.isEmpty || p.title.toLowerCase().contains(q);

    final locals = localPosts
        .where((p) => (userId == null || p.userId == userId) && matches(p))
        .toList()
      ..sort((a, b) => b.id.compareTo(a.id));

    final remote = posts.where(matches).toList()
      ..sort((a, b) =>
          sortAscending ? a.id.compareTo(b.id) : b.id.compareTo(a.id));

    return [...locals, ...remote];
  }

  PostListState copyWith({
    ListStatus? status,
    List<Post>? posts,
    List<Post>? localPosts,
    PageStatus? pageStatus,
    Object? error = _unset,
    Object? pageError = _unset,
    Object? userId = _unset,
    String? query,
    bool? sortAscending,
    int? page,
    bool? hasMore,
    bool? isRefreshing,
  }) {
    return PostListState(
      status: status ?? this.status,
      posts: posts ?? this.posts,
      localPosts: localPosts ?? this.localPosts,
      pageStatus: pageStatus ?? this.pageStatus,
      error: identical(error, _unset) ? this.error : error as AppException?,
      pageError: identical(pageError, _unset)
          ? this.pageError
          : pageError as AppException?,
      userId: identical(userId, _unset) ? this.userId : userId as int?,
      query: query ?? this.query,
      sortAscending: sortAscending ?? this.sortAscending,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      isRefreshing: isRefreshing ?? this.isRefreshing,
    );
  }
}
