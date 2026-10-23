import 'package:flutter/material.dart';
import 'package:post_explorer/data/models/comment.dart';
import 'package:post_explorer/data/models/post.dart';
import 'package:post_explorer/data/models/user.dart';
import 'package:post_explorer/data/repositories/post_repository.dart';
import 'package:post_explorer/presentation/state/async_value.dart';
import 'package:post_explorer/presentation/state/post_details_controller.dart';
import 'package:post_explorer/presentation/widgets/post_tile.dart';
import 'package:provider/provider.dart';

class PostDetailsScreen extends StatelessWidget {
  const PostDetailsScreen({super.key, required this.post});

  final Post post;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<PostDetailsController>(
      create: (ctx) =>
          PostDetailsController(ctx.read<PostRepository>(), post)..load(),
      child: const _PostDetailsView(),
    );
  }
}

class _PostDetailsView extends StatelessWidget {
  const _PostDetailsView();

  @override
  Widget build(BuildContext context) {
    final c = context.watch<PostDetailsController>();
    final post = c.post.data ?? c.initialPost;

    return Scaffold(
      appBar: AppBar(title: Text('Пост #${post.id}')),
      body: RefreshIndicator(
        onRefresh: c.load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Text(post.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (post.isLocal)
              const Align(
                alignment: Alignment.centerLeft,
                child: InfoPill(text: 'создан локально', highlighted: true),
              ),
            const SizedBox(height: 8),
            Text(post.body),
            if (c.post.error != null) ...[
              const SizedBox(height: 8),
              _InlineNote(
                text: 'Не удалось обновить пост: ${c.post.error!.message} '
                    'Показаны данные из списка.',
                onRetry: c.loadPost,
              ),
            ],
            const SizedBox(height: 16),
            _AuthorSection(value: c.author, onRetry: c.loadAuthor),
            const SizedBox(height: 16),
            _CommentsSection(
              value: c.comments,
              isLocal: c.isLocal,
              onRetry: c.loadComments,
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthorSection extends StatelessWidget {
  const _AuthorSection({required this.value, required this.onRetry});

  final AsyncValue<User> value;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final user = value.data;
    Widget content;
    if (user != null) {
      final city = user.address?.city;
      final company = user.company?.name;
      content = ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const CircleAvatar(child: Icon(Icons.person)),
        title: Text(user.name),
        subtitle: Text([
          user.email,
          if (city != null) city,
          if (company != null) company,
        ].join(' · ')),
      );
    } else if (value.status == LoadStatus.error) {
      content = _InlineNote(
        text: 'Автор: ${value.error?.message ?? 'ошибка загрузки'}',
        onRetry: onRetry,
      );
    } else {
      content = const LinearProgressIndicator();
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Автор', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            content,
          ],
        ),
      ),
    );
  }
}

class _CommentsSection extends StatelessWidget {
  const _CommentsSection({
    required this.value,
    required this.isLocal,
    required this.onRetry,
  });

  final AsyncValue<List<Comment>> value;
  final bool isLocal;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = value.data;

    Widget body;
    if (isLocal) {
      body = const Text(
        'Пост создан локально и не существует на сервере, поэтому '
        'комментариев у него нет.',
      );
    } else if (items == null) {
      body = value.status == LoadStatus.error
          ? _InlineNote(
              text: value.error?.message ?? 'Не удалось загрузить комментарии.',
              onRetry: onRetry,
            )
          : const Center(child: CircularProgressIndicator());
    } else if (items.isEmpty) {
      body = const Text('Комментариев нет.');
    } else {
      body = Column(
        children: [
          if (value.status == LoadStatus.error)
            _InlineNote(
              text: 'Не удалось обновить: ${value.error?.message}',
              onRetry: onRetry,
            ),
          for (final comment in items)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(comment.name),
              subtitle: Text('${comment.email}\n${comment.body}'),
              isThreeLine: true,
            ),
        ],
      );
    }

    final count = items == null ? '' : ' (${items.length})';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Комментарии$count', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        body,
      ],
    );
  }
}

class _InlineNote extends StatelessWidget {
  const _InlineNote({required this.text, required this.onRetry});

  final String text;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.warning_amber, color: Theme.of(context).colorScheme.error),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
        TextButton(onPressed: onRetry, child: const Text('Повторить')),
      ],
    );
  }
}
