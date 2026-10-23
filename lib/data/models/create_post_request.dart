import 'package:json_annotation/json_annotation.dart';

part 'create_post_request.g.dart';

/// Тело POST /posts. Отдельная модель, чтобы клиентские поля (isLocal)
/// не уходили на сервер.
@JsonSerializable()
class CreatePostRequest {
  const CreatePostRequest({
    required this.title,
    required this.body,
    required this.userId,
  });

  final String title;
  final String body;
  final int userId;

  factory CreatePostRequest.fromJson(Map<String, dynamic> json) =>
      _$CreatePostRequestFromJson(json);

  Map<String, dynamic> toJson() => _$CreatePostRequestToJson(this);
}
