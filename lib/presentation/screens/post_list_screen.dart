import 'package:flutter/material.dart';
import 'package:post_explorer/data/models/user.dart';
import 'package:post_explorer/presentation/screens/create_post_screen.dart';
import 'package:post_explorer/presentation/screens/post_details_screen.dart';
import 'package:post_explorer/presentation/state/async_value.dart';
import 'package:post_explorer/presentation/state/post_list_controller.dart';
import 'package:post_explorer/presentation/state/post_list_state.dart';
import 'package:post_explorer/presentation/state/users_controller.dart';
import 'package:post_explorer/presentation/widgets/error_view.dart';
import 'package:post_explorer/presentation/widgets/post_tile.dart';
import 'package:provider/provider.dart';

class PostListScreen extends StatefulWidget {
  const PostListScreen({super.key});

  @override
  State<PostListScreen> createState() => _PostListScreenState();
}

class _PostListScreenState extends State<PostListScreen> {
  final ScrollController _scroll = ScrollController();
  final TextEditingController _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    if (position.pixels >= position.maxScrollExtent - 240) {
      context.read<PostListController>().loadNextPage();
    }
  }

  /// Если 10 постов не заполняют экран, прокрутки нет и событие скролла
  /// не придёт — догружаем страницу сами (только без активного поиска).
  void _fillViewportIfNeeded() {
    if (!mounted || !_scroll.hasClients) return;
    final controller = context.read<PostListController>();
    if (controller.state.query.trim().isNotEmpty) return;
    if (_scroll.position.maxScrollExtent <= 0) {
      controller.loadNextPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PostListController>();
    final state = controller.state;

    WidgetsBinding.instance.addPostFrameCallback((_) => _fillViewportIfNeeded());

    return Scaffold(
      appBar: AppBar(title: const Text('Post Explorer')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const CreatePostScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Создать пост'),
      ),
      body: Column(
        children: [
          _buildFilters(context, controller),
          if (state.status == ListStatus.cached)
            _CachedBanner(state: state, onRetry: controller.refresh),
          Expanded(child: _buildBody(context, controller)),
        ],
      ),
    );
  }

  // ---------- Фильтры ----------

  Widget _buildFilters(BuildContext context, PostListController controller) {
    final state = controller.state;
    final usersController = context.watch<UsersController>();
    final users = usersController.state.data ?? const <User>[];
    final selectedUser = users.any((u) => u.id == state.userId)
        ? state.userId
        : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Column(
        children: [
          TextField(
            controller: _search,
            onChanged: controller.setQuery,
            decoration: InputDecoration(
              isDense: true,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.search),
              labelText: 'Поиск по заголовку',
              helperText:
                  'Поиск только среди загруженных постов (${state.posts.length}), не по всему набору данных',
              helperMaxLines: 2,
              suffixIcon: state.query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _search.clear();
                        controller.setQuery('');
                      },
                    ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: DropdownButton<int?>(
                  isExpanded: true,
                  value: selectedUser,
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Все авторы'),
                    ),
                    ...users.map(
                      (u) => DropdownMenuItem<int?>(
                        value: u.id,
                        child: Text(u.name, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ],
                  onChanged: controller.setUserFilter,
                ),
              ),
              if (usersController.state.status == LoadStatus.error &&
                  users.isEmpty)
                IconButton(
                  tooltip: 'Не удалось загрузить авторов. Повторить',
                  icon: const Icon(Icons.sync_problem),
                  onPressed: usersController.load,
                ),
              IconButton(
                tooltip: state.sortAscending
                    ? 'Сортировка по ID: по возрастанию'
                    : 'Сортировка по ID: по убыванию',
                icon: Icon(
                  state.sortAscending
                      ? Icons.arrow_upward
                      : Icons.arrow_downward,
                ),
                onPressed: controller.toggleSort,
              ),
              TextButton.icon(
                onPressed: state.hasActiveFilters
                    ? () {
                        _search.clear();
                        controller.resetFilters();
                      }
                    : null,
                icon: const Icon(Icons.filter_alt_off),
                label: const Text('Сброс'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------- Тело ----------

  Widget _buildBody(BuildContext context, PostListController controller) {
    final state = controller.state;

    if (state.status == ListStatus.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.status == ListStatus.error) {
      return ErrorView(
        message: state.error?.message ?? 'Не удалось загрузить посты.',
        onRetry: controller.refresh,
      );
    }

    final posts = state.visiblePosts;
    final users = context.watch<UsersController>();

    if (posts.isEmpty) {
      final searching = state.query.trim().isNotEmpty;
      return RefreshIndicator(
        onRefresh: controller.refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 80),
            EmptyView(
              icon: searching ? Icons.search_off : Icons.inbox,
              message: searching
                  ? 'Среди загруженных постов ничего не найдено.\n'
                      'Поиск не обращается к серверу — загрузите больше постов '
                      'или измените запрос.'
                  : 'Постов нет.',
            ),
            if (searching && state.hasMore)
              Center(
                child: TextButton(
                  onPressed: controller.loadNextPage,
                  child: const Text('Загрузить ещё посты'),
                ),
              ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: ListView.builder(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 88),
        itemCount: posts.length + 1,
        itemBuilder: (context, index) {
          if (index == posts.length) {
            return _ListFooter(state: state, controller: controller);
          }
          final post = posts[index];
          return PostTile(
            key: ValueKey('${post.isLocal}-${post.id}'),
            post: post,
            authorName: users.nameOf(post.userId),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => PostDetailsScreen(post: post),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Плашка «показаны сохранённые данные».
class _CachedBanner extends StatelessWidget {
  const _CachedBanner({required this.state, required this.onRetry});

  final PostListState state;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final updating = state.isRefreshing;
    return Material(
      color: scheme.secondaryContainer,
      child: Column(
        children: [
          if (updating) const LinearProgressIndicator(minHeight: 2),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.history, size: 18, color: scheme.onSecondaryContainer),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    updating
                        ? 'Показаны сохранённые данные. Обновляем…'
                        : 'Показаны сохранённые данные. '
                            '${state.error?.message ?? 'Не удалось обновить.'}',
                    style: TextStyle(
                      fontSize: 13,
                      color: scheme.onSecondaryContainer,
                    ),
                  ),
                ),
                if (!updating)
                  TextButton(onPressed: onRetry, child: const Text('Обновить')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Низ списка: индикатор, ошибка с повтором, кнопка или «всё загружено».
class _ListFooter extends StatelessWidget {
  const _ListFooter({required this.state, required this.controller});

  final PostListState state;
  final PostListController controller;

  @override
  Widget build(BuildContext context) {
    if (state.pageStatus == PageStatus.loading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (state.pageStatus == PageStatus.error) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              state.pageError?.message ??
                  'Не удалось загрузить следующую страницу.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: controller.retryNextPage,
              icon: const Icon(Icons.refresh),
              label: const Text('Повторить'),
            ),
          ],
        ),
      );
    }

    if (!state.hasMore) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: Text('Все посты загружены')),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(8),
      child: Center(
        child: TextButton(
          onPressed: controller.loadNextPage,
          child: const Text('Загрузить ещё'),
        ),
      ),
    );
  }
}
