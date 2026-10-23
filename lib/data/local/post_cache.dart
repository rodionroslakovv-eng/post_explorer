import 'dart:convert';

import 'package:post_explorer/data/models/post.dart';
import 'package:post_explorer/data/models/user.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Локальный кэш. Интерфейс отделён от реализации, чтобы в тестах
/// подставлять in-memory версию.
abstract class PostCache {
  /// Последний успешно загруженный список постов (для всех или для автора).
  Future<List<Post>?> readPosts({int? userId});
  Future<void> writePosts(List<Post> posts, {int? userId});

  /// Посты, созданные пользователем локально.
  Future<List<Post>> readLocalPosts();
  Future<void> writeLocalPosts(List<Post> posts);

  Future<List<User>?> readUsers();
  Future<void> writeUsers(List<User> users);
}

class SharedPrefsPostCache implements PostCache {
  SharedPrefsPostCache(this._prefs);

  final SharedPreferences _prefs;

  static const _postsAllKey = 'cache_posts_all';
  static const _postsUserPrefix = 'cache_posts_user_';
  static const _localPostsKey = 'cache_posts_local';
  static const _usersKey = 'cache_users';

  String _postsKey(int? userId) =>
      userId == null ? _postsAllKey : '$_postsUserPrefix$userId';

  @override
  Future<List<Post>?> readPosts({int? userId}) async =>
      _decodeList(_prefs.getString(_postsKey(userId)), Post.fromJson);

  @override
  Future<void> writePosts(List<Post> posts, {int? userId}) =>
      _prefs.setString(_postsKey(userId), _encodeList(posts.map((p) => p.toJson())));

  @override
  Future<List<Post>> readLocalPosts() async =>
      _decodeList(_prefs.getString(_localPostsKey), Post.fromJson) ?? const [];

  @override
  Future<void> writeLocalPosts(List<Post> posts) =>
      _prefs.setString(_localPostsKey, _encodeList(posts.map((p) => p.toJson())));

  @override
  Future<List<User>?> readUsers() async =>
      _decodeList(_prefs.getString(_usersKey), User.fromJson);

  @override
  Future<void> writeUsers(List<User> users) =>
      _prefs.setString(_usersKey, _encodeList(users.map((u) => u.toJson())));

  String _encodeList(Iterable<Map<String, dynamic>> items) =>
      jsonEncode(items.toList());

  /// Повреждённый кэш не должен ронять приложение — считаем его пустым.
  List<T>? _decodeList<T>(
    String? raw,
    T Function(Map<String, dynamic> json) parse,
  ) {
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return null;
      return decoded
          .map((e) => parse(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return null;
    }
  }
}
