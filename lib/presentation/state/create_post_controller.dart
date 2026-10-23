import 'package:flutter/foundation.dart';
import 'package:post_explorer/core/error/app_exception.dart';
import 'package:post_explorer/data/repositories/post_repository.dart';

/// Состояние отправки формы — отдельно от загрузки списка.
enum SubmitStatus { idle, submitting, success, failure }

class CreatePostController extends ChangeNotifier {
  CreatePostController(this._repository);

  final PostRepository _repository;

  SubmitStatus _status = SubmitStatus.idle;
  CreatePostResult? _result;
  AppException? _error;
  bool _disposed = false;

  SubmitStatus get status => _status;
  CreatePostResult? get result => _result;
  AppException? get error => _error;
  bool get isSubmitting => _status == SubmitStatus.submitting;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// Повторное нажатие во время запроса игнорируется.
  Future<CreatePostResult?> submit({
    required String title,
    required String body,
    required int userId,
  }) async {
    if (isSubmitting) return null;
    _status = SubmitStatus.submitting;
    _result = null;
    _error = null;
    _notify();
    try {
      final result = await _repository.createPost(
        title: title,
        body: body,
        userId: userId,
      );
      _status = SubmitStatus.success;
      _result = result;
      _notify();
      return result;
    } catch (e) {
      _status = SubmitStatus.failure;
      _error = AppException.from(e);
      _notify();
      return null;
    }
  }

  void reset() {
    _status = SubmitStatus.idle;
    _result = null;
    _error = null;
    _notify();
  }
}
