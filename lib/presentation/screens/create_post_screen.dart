import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:post_explorer/core/utils/validators.dart';
import 'package:post_explorer/data/models/user.dart';
import 'package:post_explorer/data/repositories/post_repository.dart';
import 'package:post_explorer/presentation/state/async_value.dart';
import 'package:post_explorer/presentation/state/create_post_controller.dart';
import 'package:post_explorer/presentation/state/post_list_controller.dart';
import 'package:post_explorer/presentation/state/users_controller.dart';
import 'package:provider/provider.dart';

class CreatePostScreen extends StatelessWidget {
  const CreatePostScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<CreatePostController>(
      create: (ctx) => CreatePostController(ctx.read<PostRepository>()),
      child: const _CreatePostForm(),
    );
  }
}

class _CreatePostForm extends StatefulWidget {
  const _CreatePostForm();

  @override
  State<_CreatePostForm> createState() => _CreatePostFormState();
}

class _CreatePostFormState extends State<_CreatePostForm> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _body = TextEditingController();
  int? _userId;
  int _formVersion = 0;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final controller = context.read<CreatePostController>();
    if (controller.isSubmitting) return; // защита от повторного нажатия
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final listController = context.read<PostListController>();
    final result = await controller.submit(
      title: _title.text,
      body: _body.text,
      userId: _userId!,
    );
    if (!mounted) return;

    if (result != null) {
      listController.addLocalPost(result.localPost);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(controller.error?.message ?? 'Ошибка отправки')),
      );
    }
  }

  void _createAnother() {
    _title.clear();
    _body.clear();
    setState(() {
      _userId = null;
      _formVersion++; // пересоздаёт поле выбора автора
    });
    context.read<CreatePostController>().reset();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<CreatePostController>();
    final usersController = context.watch<UsersController>();
    final users = usersController.state.data ?? const <User>[];
    final submitting = controller.isSubmitting;
    final done = controller.status == SubmitStatus.success;

    return Scaffold(
      appBar: AppBar(title: const Text('Новый пост')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _title,
                    enabled: !submitting && !done,
                    maxLength: PostValidators.titleMax,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Заголовок',
                      helperText: 'От 5 до 100 символов',
                      border: OutlineInputBorder(),
                    ),
                    validator: PostValidators.title,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _body,
                    enabled: !submitting && !done,
                    maxLength: PostValidators.bodyMax,
                    minLines: 4,
                    maxLines: 8,
                    decoration: const InputDecoration(
                      labelText: 'Текст поста',
                      helperText: 'От 10 до 1000 символов',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                    ),
                    validator: PostValidators.body,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    key: ValueKey(_formVersion),
                    value: _userId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Автор',
                      border: OutlineInputBorder(),
                    ),
                    items: users
                        .map(
                          (u) => DropdownMenuItem<int>(
                            value: u.id,
                            child: Text(u.name, overflow: TextOverflow.ellipsis),
                          ),
                        )
                        .toList(),
                    onChanged: (submitting || done)
                        ? null
                        : (value) => setState(() => _userId = value),
                    validator: PostValidators.userId,
                  ),
                  if (users.isEmpty) ...[
                    const SizedBox(height: 8),
                    _UsersHint(
                      value: usersController.state,
                      onRetry: usersController.load,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (!done)
              FilledButton.icon(
                // во время запроса кнопка заблокирована
                onPressed: submitting ? null : _submit,
                icon: submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                label: Text(submitting ? 'Отправка…' : 'Отправить'),
              ),
            if (controller.status == SubmitStatus.failure &&
                controller.error != null) ...[
              const SizedBox(height: 12),
              Text(
                controller.error!.message,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            if (done && controller.result != null)
              _ResultCard(
                result: controller.result!,
                onCreateAnother: _createAnother,
                onClose: () => Navigator.of(context).pop(),
              ),
          ],
        ),
      ),
    );
  }
}

class _UsersHint extends StatelessWidget {
  const _UsersHint({required this.value, required this.onRetry});

  final AsyncValue<List<User>> value;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    if (value.status == LoadStatus.error) {
      return Row(
        children: [
          Expanded(
            child: Text(value.error?.message ?? 'Не удалось загрузить авторов.'),
          ),
          TextButton(onPressed: onRetry, child: const Text('Повторить')),
        ],
      );
    }
    return const Row(
      children: [
        SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        SizedBox(width: 8),
        Text('Загружаем список авторов…'),
      ],
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.result,
    required this.onCreateAnother,
    required this.onClose,
  });

  final CreatePostResult result;
  final VoidCallback onCreateAnother;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final server = result.serverPost;
    final pretty = const JsonEncoder.withIndent('  ').convert({
      'id': server.id,
      'userId': server.userId,
      'title': server.title,
      'body': server.body,
    });

    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.check_circle,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Ответ сервера (POST /posts)',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            SelectableText(
              pretty,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            ),
            const SizedBox(height: 12),
            Text(
              'JSONPlaceholder только имитирует создание и ничего не сохраняет '
              '(id всегда 101). Пост добавлен в локальный список с пометкой '
              '«создан локально», локальный id: ${result.localPost.id}.',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(
                  onPressed: onCreateAnother,
                  child: const Text('Создать ещё'),
                ),
                FilledButton(onPressed: onClose, child: const Text('К списку')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
