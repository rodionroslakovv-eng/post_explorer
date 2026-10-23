import 'package:dio/dio.dart';
import 'package:post_explorer/data/models/comment.dart';
import 'package:post_explorer/data/models/create_post_request.dart';
import 'package:post_explorer/data/models/post.dart';
import 'package:post_explorer/data/models/user.dart';
import 'package:retrofit/retrofit.dart';

part 'post_api.g.dart';

/// Все запросы к JSONPlaceholder описаны здесь, одним Retrofit-интерфейсом.
/// Код реализации (_PostApi) генерирует retrofit_generator.
@RestApi()
abstract class PostApi {
  factory PostApi(Dio dio, {String? baseUrl}) = _PostApi;

  /// 1. GET /posts?_page=1&_limit=10 — список с пагинацией
  @GET('/posts')
  Future<List<Post>> getPosts(
    @Query('_page') int page,
    @Query('_limit') int limit, {
    @CancelRequest() CancelToken? cancelToken,
  });

  /// 2. GET /posts/{id} — подробности поста
  @GET('/posts/{id}')
  Future<Post> getPost(
    @Path('id') int id, {
    @CancelRequest() CancelToken? cancelToken,
  });

  /// 3. GET /posts?userId={id} — посты автора (с той же пагинацией)
  @GET('/posts')
  Future<List<Post>> getPostsByUser(
    @Query('userId') int userId,
    @Query('_page') int page,
    @Query('_limit') int limit, {
    @CancelRequest() CancelToken? cancelToken,
  });

  /// 4. GET /posts/{id}/comments — комментарии
  @GET('/posts/{id}/comments')
  Future<List<Comment>> getComments(@Path('id') int postId);

  /// 5. POST /posts — создание поста
  @POST('/posts')
  Future<Post> createPost(@Body() CreatePostRequest request);

  /// Доп.: GET /users — список авторов
  @GET('/users')
  Future<List<User>> getUsers();

  /// Доп.: GET /users/{id} — автор
  @GET('/users/{id}')
  Future<User> getUser(@Path('id') int id);
}
