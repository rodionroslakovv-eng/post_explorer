import 'package:json_annotation/json_annotation.dart';

part 'post.g.dart';

@JsonSerializable()
class Post {
  const Post({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    this.isLocal = false,
  });

  final int id;
  final int userId;
  final String title;
  final String body;

  /// Пост создан в приложении и не хранится на сервере (JSONPlaceholder
  /// не сохраняет POST). Поле только клиентское, сервер его не присылает.
  @JsonKey(defaultValue: false)
  final bool isLocal;

  factory Post.fromJson(Map<String, dynamic> json) => _$PostFromJson(json);

  Map<String, dynamic> toJson() => _$PostToJson(this);

  Post copyWith({
    int? id,
    int? userId,
    String? title,
    String? body,
    bool? isLocal,
  }) =>
      Post(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        title: title ?? this.title,
        body: body ?? this.body,
        isLocal: isLocal ?? this.isLocal,
      );
}
