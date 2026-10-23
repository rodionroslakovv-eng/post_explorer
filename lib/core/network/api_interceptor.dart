import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:post_explorer/core/error/app_exception.dart';

/// Добавляет технические заголовки к каждому запросу.
class ApiInterceptor extends Interceptor {
  ApiInterceptor({
    this.clientName = 'post_explorer',
    this.clientVersion = '1.0.0',
  });

  final String clientName;
  final String clientVersion;
  int _counter = 0;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    _counter++;
    options.headers.addAll({
      'Accept': 'application/json',
      'X-Client-Name': clientName,
      'X-Client-Version': clientVersion,
      'X-Request-Id': '${DateTime.now().microsecondsSinceEpoch}-$_counter',
    });
    handler.next(options);
  }
}

/// Централизованная обработка HTTP-ошибок: любой DioException превращается
/// в [AppException] с понятным пользователю текстом.
/// Технические детали уходят только в лог разработки.
class ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final exception = AppException.fromDio(err);
    if (kDebugMode && !exception.isCancelled) {
      debugPrint('[HTTP error] ${exception.type.name}: ${exception.technical}');
    }
    handler.next(err.copyWith(error: exception));
  }
}
