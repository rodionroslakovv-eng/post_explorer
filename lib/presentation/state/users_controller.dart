import 'package:flutter/foundation.dart';
import 'package:post_explorer/core/error/app_exception.dart';
import 'package:post_explorer/data/models/user.dart';
import 'package:post_explorer/data/repositories/post_repository.dart';
import 'package:post_explorer/presentation/state/async_value.dart';

/// Список авторов: нужен фильтру на главном экране и форме создания.
class UsersController extends ChangeNotifier {
  UsersController(this._repository);

  final PostRepository _repository;

  AsyncValue<List<User>> _state = const AsyncValue.loading();
  AsyncValue<List<User>> get state => _state;

  bool _disposed = false;

  void _set(AsyncValue<List<User>> next) {
    _state = next;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> load() async {
    final cached = await _repository.readCachedUsers();
    if (cached.isNotEmpty) {
      _set(AsyncValue<List<User>>.loading(cached));
    } else {
      _set(const AsyncValue<List<User>>.loading());
    }
    try {
      final users = await _repository.fetchUsers();
      _set(AsyncValue<List<User>>.success(users));
    } catch (e) {
      _set(AsyncValue<List<User>>.failure(
        AppException.from(e),
        cached.isEmpty ? null : cached,
      ));
    }
  }

  String nameOf(int userId) {
    final users = _state.data;
    if (users != null) {
      for (final u in users) {
        if (u.id == userId) return u.name;
      }
    }
    return 'Автор #$userId';
  }
}
