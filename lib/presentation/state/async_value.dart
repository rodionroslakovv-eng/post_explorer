import 'package:post_explorer/core/error/app_exception.dart';

enum LoadStatus { loading, success, error }

/// Состояние одной независимой загрузки (автор, комментарии, пользователи).
/// [data] может быть заполнен и при loading/error — это «устаревшие, но
/// последние успешные» данные, которые не нужно прятать от пользователя.
class AsyncValue<T> {
  const AsyncValue._(this.status, this.data, this.error);

  const AsyncValue.loading([T? data]) : this._(LoadStatus.loading, data, null);

  const AsyncValue.success(T data) : this._(LoadStatus.success, data, null);

  const AsyncValue.failure(AppException error, [T? data])
      : this._(LoadStatus.error, data, error);

  final LoadStatus status;
  final T? data;
  final AppException? error;

  bool get hasData => data != null;
  bool get isLoading => status == LoadStatus.loading;
}
