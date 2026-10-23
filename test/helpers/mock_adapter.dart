import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:post_explorer/core/network/dio_client.dart';

typedef MockHandler = Future<ResponseBody> Function(RequestOptions options);

/// Mock-адаптер Dio: тесты не ходят в реальную сеть.
class MockAdapter implements HttpClientAdapter {
  MockAdapter(this.handler);

  final MockHandler handler;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests.add(options);
    return handler(options);
  }

  @override
  void close({bool force = false}) {}

  static ResponseBody json(Object body, {int status = 200}) {
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  /// Dio с тем же набором interceptors, что и в приложении.
  static Dio dioWith(MockAdapter adapter) =>
      DioClient.create(adapter: adapter, enableLogs: false);
}
