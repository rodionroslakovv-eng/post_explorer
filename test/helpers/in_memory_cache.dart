import 'package:post_explorer/data/local/post_cache.dart';
import 'package:post_explorer/data/models/post.dart';
import 'package:post_explorer/data/models/user.dart';

class InMemoryPostCache implements PostCache {
  final Map<int?, List<Post>> posts = {};
  List<Post> localPosts = [];
  List<User>? users;

  @override
  Future<List<Post>?> readPosts({int? userId}) async => posts[userId];

  @override
  Future<void> writePosts(List<Post> value, {int? userId}) async {
    posts[userId] = List<Post>.of(value);
  }

  @override
  Future<List<Post>> readLocalPosts() async => List<Post>.of(localPosts);

  @override
  Future<void> writeLocalPosts(List<Post> value) async {
    localPosts = List<Post>.of(value);
  }

  @override
  Future<List<User>?> readUsers() async => users;

  @override
  Future<void> writeUsers(List<User> value) async {
    users = List<User>.of(value);
  }
}
