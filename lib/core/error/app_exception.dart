import 'dart:io' show SocketException;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:json_annotation/json_annotation.dart';

/// Категории ошибок, которые различает приложение (раздел 6 задания).
enum AppErrorType {
  noConnection,
  timeout,
  client, // HTTP 4xx
  server, // HTTP 5xx
  parse, // ошибка преобразования JSON
  cancelled, // служебный тип: запрос отменён нами же
  unknown,
}

/// Единое исключение приложения. UI видит только [message],
/// технические детали лежат в [technical] и пишутся в лог.
@immutable
class AppException implements Exception {
  const AppException({
    required this.type,
    required this.message,
    this.statusCode,
    this.technical,
  });

  final AppErrorType type;
  final String message;
  final int? statusCode;
  final String? technical;

  bool get isCancelled => type == AppErrorType.cancelled;

  /// Приводит любую ошибку (DioException, TypeError, FormatException...) к [AppException].
  factory AppException.from(Object error) {
    if (error is AppException) return error;
    if (error is DioException) {
      final inner = error.error;
      if (inner is AppException) return inner;
      return AppException.fromDio(error);
    }
    if (_isParseError(error)) return AppException._parse(error);
    return AppException(
      type: AppErrorType.unknown,
      message: 'Произошла неизвестная ошибка. Попробуйте ещё раз.',
      technical: error.toString(),
    );
  }

  factory AppException.fromDio(DioException e) {
    final technical =
        '${e.type.name} ${e.requestOptions.method} ${e.requestOptions.uri} '
        'status=${e.response?.statusCode} ${e.message ?? ''}';

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return AppException(
          type: AppErrorType.timeout,
          message: 'Сервер слишком долго отвечает. Попробуйте ещё раз.',
          technical: technical,
        );
      case DioExceptionType.connectionError:
        return AppException(
          type: AppErrorType.noConnection,
          message: 'Нет подключения к интернету. Проверьте сеть и повторите попытку.',
          technical: technical,
        );
      case DioExceptionType.cancel:
        return AppException(
          type: AppErrorType.cancelled,
          message: 'Запрос отменён.',
          technical: technical,
        );
      case DioExceptionType.badResponse:
        final code = e.response?.statusCode;
        if (code != null && code >= 500) {
          return AppException(
            type: AppErrorType.server,
            statusCode: code,
            message: 'Сервер временно недоступен (код $code). Попробуйте позже.',
            technical: technical,
          );
        }
        if (code != null && code >= 400) {
          return AppException(
            type: AppErrorType.client,
            statusCode: code,
            message: code == 404
                ? 'Данные не найдены (404).'
                : 'Некорректный запрос (код $code).',
            technical: technical,
          );
        }
        return AppException(
          type: AppErrorType.unknown,
          statusCode: code,
          message: 'Неожиданный ответ сервера.',
          technical: technical,
        );
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        final inner = e.error;
        if (inner is SocketException) {
          return AppException(
            type: AppErrorType.noConnection,
            message: 'Нет подключения к интернету. Проверьте сеть и повторите попытку.',
            technical: technical,
          );
        }
        if (inner != null && _isParseError(inner)) {
          return AppException._parse(inner);
        }
        return AppException(
          type: AppErrorType.unknown,
          message: 'Произошла неизвестная ошибка. Попробуйте ещё раз.',
          technical: '$technical ${inner ?? ''}',
        );
      default:
        // Новые значения enum в свежих версиях Dio (например, transformTimeout).
        final isTimeout = e.type.name.toLowerCase().contains('timeout');
        return AppException(
          type: isTimeout ? AppErrorType.timeout : AppErrorType.unknown,
          message: isTimeout
              ? 'Сервер слишком долго отвечает. Попробуйте ещё раз.'
              : 'Произошла неизвестная ошибка. Попробуйте ещё раз.',
          technical: technical,
        );
    }
  }

  factory AppException._parse(Object error) => AppException(
        type: AppErrorType.parse,
        message: 'Не удалось обработать ответ сервера: данные имеют неверный формат.',
        technical: error.toString(),
      );

  static bool _isParseError(Object e) =>
      e is FormatException ||
      e is TypeError ||
      e is CheckedFromJsonException ||
      e is BadKeyException;

  @override
  String toString() => 'AppException($type, status=$statusCode, $technical)';
}
