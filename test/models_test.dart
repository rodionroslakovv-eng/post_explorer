import 'package:flutter_test/flutter_test.dart';
import 'package:post_explorer/core/error/app_exception.dart';
import 'package:post_explorer/data/models/comment.dart';
import 'package:post_explorer/data/models/create_post_request.dart';
import 'package:post_explorer/data/models/post.dart';
import 'package:post_explorer/data/models/user.dart';

void main() {
  group('Post JSON', () {
    test('1. успешное преобразование JSON в Post', () {
      final post = Post.fromJson({
        'userId': 1,
        'id': 7,
        'title': 'hello',
        'body': 'world',
      });

      expect(post.id, 7);
      expect(post.userId, 1);
      expect(post.title, 'hello');
      expect(post.body, 'world');
      expect(post.isLocal, isFalse); // сервер этого поля не присылает
    });

    test('2. преобразование Post обратно в JSON', () {
      const post = Post(id: 3, userId: 2, title: 't', body: 'b');

      expect(post.toJson(), {
        'id': 3,
        'userId': 2,
        'title': 't',
        'body': 'b',
        'isLocal': false,
      });
    });

    test('круговое преобразование сохраняет isLocal', () {
      const post = Post(id: 101, userId: 1, title: 't', body: 'b', isLocal: true);
      final restored = Post.fromJson(post.toJson());
      expect(restored.isLocal, isTrue);
      expect(restored.id, 101);
    });

    test('отсутствует обязательное поле -> TypeError -> AppException(parse)', () {
      final broken = <String, dynamic>{'id': 1, 'userId': 1, 'body': 'b'};

      Object? caught;
      try {
        Post.fromJson(broken);
      } catch (e) {
        caught = e;
      }

      expect(caught, isA<TypeError>());
      expect(AppException.from(caught!).type, AppErrorType.parse);
    });
  });

  group('User (вложенные модели)', () {
    test('разбирает address, geo и company', () {
      final user = User.fromJson({
        'id': 1,
        'name': 'Leanne Graham',
        'username': 'Bret',
        'email': 'sincere@april.biz',
        'address': {
          'street': 'Kulas Light',
          'city': 'Gwenborough',
          'geo': {'lat': '-37.3159', 'lng': '81.1496'},
        },
        'company': {'name': 'Romaguera-Crona'},
      });

      expect(user.address?.city, 'Gwenborough');
      expect(user.address?.geo?.lat, '-37.3159');
      expect(user.company?.name, 'Romaguera-Crona');
      // вложенные объекты сериализуются обратно
      final json = user.toJson();
      expect((json['address'] as Map)['city'], 'Gwenborough');
    });

    test('необязательные поля могут отсутствовать', () {
      final user = User.fromJson({
        'id': 2,
        'name': 'N',
        'username': 'n',
        'email': 'n@n.n',
      });

      expect(user.address, isNull);
      expect(user.company, isNull);
      expect(user.phone, isNull);
    });
  });

  test('Comment.fromJson', () {
    final c = Comment.fromJson({
      'postId': 1,
      'id': 5,
      'name': 'n',
      'email': 'e@e.e',
      'body': 'b',
    });
    expect(c.postId, 1);
    expect(c.email, 'e@e.e');
  });

  test('CreatePostRequest не содержит клиентских полей', () {
    const request = CreatePostRequest(title: 't', body: 'b', userId: 4);
    expect(request.toJson(), {'title': 't', 'body': 'b', 'userId': 4});
  });
}
