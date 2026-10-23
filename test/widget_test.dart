import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:post_explorer/data/models/post.dart';
import 'package:post_explorer/presentation/widgets/post_tile.dart';

void main() {
  testWidgets('PostTile показывает пометку «создан локально»', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PostTile(
            post: const Post(
              id: 101,
              userId: 1,
              title: 'Local title',
              body: 'Local body',
              isLocal: true,
            ),
            authorName: 'Leanne Graham',
            onTap: () {},
          ),
        ),
      ),
    );

    expect(find.text('Local title'), findsOneWidget);
    expect(find.text('создан локально'), findsOneWidget);
    expect(find.text('Leanne Graham'), findsOneWidget);
  });

  testWidgets('PostTile без пометки для серверного поста', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PostTile(
            post: const Post(id: 1, userId: 1, title: 'Server', body: 'Body'),
            authorName: 'A',
            onTap: () {},
          ),
        ),
      ),
    );

    expect(find.text('создан локально'), findsNothing);
  });
}
