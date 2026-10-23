import 'package:flutter_test/flutter_test.dart';
import 'package:post_explorer/core/utils/validators.dart';
import 'package:post_explorer/data/local/post_cache.dart';
import 'package:post_explorer/data/models/post.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SharedPrefsPostCache', () {
    test('сохраняет и читает посты (отдельно для всех и для автора)', () async {
      SharedPreferences.setMockInitialValues({});
      final cache = SharedPrefsPostCache(await SharedPreferences.getInstance());

      expect(await cache.readPosts(), isNull);

      await cache.writePosts(
        const [Post(id: 1, userId: 1, title: 'a title', body: 'a body')],
      );
      await cache.writePosts(
        const [Post(id: 15, userId: 2, title: 'b title', body: 'b body')],
        userId: 2,
      );

      expect((await cache.readPosts())!.single.id, 1);
      expect((await cache.readPosts(userId: 2))!.single.id, 15);
    });

    test('повреждённый кэш считается пустым и не роняет приложение', () async {
      SharedPreferences.setMockInitialValues({'cache_posts_all': '{not json'});
      final cache = SharedPrefsPostCache(await SharedPreferences.getInstance());

      expect(await cache.readPosts(), isNull);
    });
  });

  group('PostValidators', () {
    test('title: 5..100 символов', () {
      expect(PostValidators.title(''), isNotNull);
      expect(PostValidators.title('abcd'), isNotNull);
      expect(PostValidators.title('abcde'), isNull);
      expect(PostValidators.title('a' * 100), isNull);
      expect(PostValidators.title('a' * 101), isNotNull);
    });

    test('body: 10..1000 символов', () {
      expect(PostValidators.body('123456789'), isNotNull);
      expect(PostValidators.body('1234567890'), isNull);
      expect(PostValidators.body('a' * 1000), isNull);
      expect(PostValidators.body('a' * 1001), isNotNull);
    });

    test('пробелы по краям не считаются', () {
      expect(PostValidators.title('   ab   '), isNotNull);
    });

    test('userId обязателен', () {
      expect(PostValidators.userId(null), isNotNull);
      expect(PostValidators.userId(3), isNull);
    });
  });
}
