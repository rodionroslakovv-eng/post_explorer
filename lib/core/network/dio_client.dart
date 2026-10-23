import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:post_explorer/core/network/api_interceptor.dart';

/// Фабрика единственного экземпляра Dio. Создаётся один раз в main()
/// и передаётся в Retrofit-клиент. Новый Dio на запрос не создаётся.
class DioClient {
  DioClient._();

  static const String defaultBaseUrl = 'https://jsonplaceholder.typicode.com';

  static Dio create({
    String baseUrl = defaultBaseUrl,
    HttpClientAdapter? adapter,
    bool enableLogs = kDebugMode,
  }) {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        sendTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        responseType: ResponseType.json,
        contentType: Headers.jsonContentType,
      ),
    );

    if (adapter != null) {
      dio.httpClientAdapter = adapter; // подмена адаптера в тестах
    }

    dio.interceptors.addAll([
      ApiInterceptor(),
      if (enableLogs)
        LogInterceptor(
          requestHeader: false,
          requestBody: true,
          responseBody: false,
          logPrint: (object) => debugPrint(object.toString()),
        ),
      ErrorInterceptor(), // последним: оборачивает ошибку после логирования
    ]);

    return dio;
  }
}
