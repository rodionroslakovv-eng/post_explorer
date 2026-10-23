import 'package:flutter/material.dart';
import 'package:post_explorer/core/network/dio_client.dart';
import 'package:post_explorer/data/local/post_cache.dart';
import 'package:post_explorer/data/remote/post_api.dart';
import 'package:post_explorer/data/repositories/post_repository.dart';
import 'package:post_explorer/presentation/screens/post_list_screen.dart';
import 'package:post_explorer/presentation/state/post_list_controller.dart';
import 'package:post_explorer/presentation/state/users_controller.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Сборка зависимостей: один Dio -> Retrofit -> Repository (+ кэш).
  final prefs = await SharedPreferences.getInstance();
  final dio = DioClient.create();
  final repository = PostRepositoryImpl(
    api: PostApi(dio),
    cache: SharedPrefsPostCache(prefs),
  );

  runApp(PostExplorerApp(repository: repository));
}

class PostExplorerApp extends StatelessWidget {
  const PostExplorerApp({super.key, required this.repository});

  final PostRepository repository;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<PostRepository>.value(value: repository),
        ChangeNotifierProvider<PostListController>(
          create: (_) => PostListController(repository)..init(),
        ),
        ChangeNotifierProvider<UsersController>(
          create: (_) => UsersController(repository)..load(),
        ),
      ],
      child: MaterialApp(
        title: 'Post Explorer',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorSchemeSeed: Colors.indigo,
          useMaterial3: true,
        ),
        home: const PostListScreen(),
      ),
    );
  }
}
