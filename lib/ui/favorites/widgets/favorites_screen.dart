import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../domain/models/recipe.dart';
import '../../../routing/routes.dart';
import '../../core/themes/spacing.dart';
import '../../core/ui/load_feedback.dart';
import '../../core/ui/recipe_image.dart';
import '../../core/view_state.dart';
import '../view_models/favorites_viewmodel.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(context.read<FavoritesViewModel>().load());
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<FavoritesViewModel>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: const Icon(Icons.menu),
        title: Text(
          'O Que Comer',
          style: theme.textTheme.titleLarge?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: AppSpacing.x4),
            child: Icon(Icons.account_circle_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: _Body(vm: vm),
          ),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.vm});

  final FavoritesViewModel vm;

  @override
  Widget build(BuildContext context) {
    switch (vm.state) {
      case ViewState.loading:
        return const Center(child: CircularProgressIndicator());
      case ViewState.error:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Erro: ${vm.errorMessage}'),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: context.read<FavoritesViewModel>().load,
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        );
      case ViewState.success:
        if (vm.favorites.isEmpty) {
          return const _EmptyFavorites();
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.x4,
            AppSpacing.x5,
            AppSpacing.x4,
            AppSpacing.x4,
          ),
          children: [
            Text(
              'Meus Favoritos',
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSpacing.x2),
            Text(
              'Suas receitas salvas prontas para inspirar '
              'sua próxima refeição.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.x6),
            for (final favorite in vm.favorites) ...[
              _FavoriteCard(recipe: favorite),
              if (favorite != vm.favorites.last)
                const SizedBox(height: AppSpacing.x4),
            ],
          ],
        );
    }
  }
}

class _FavoriteCard extends StatelessWidget {
  const _FavoriteCard({required this.recipe});

  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final category = recipe.type?.trim().isNotEmpty == true
        ? recipe.type!.trim()
        : recipe.source == RecipeSource.ai
        ? 'Receita com IA'
        : 'Receita';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(Routes.recipeDetails(recipe.id)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: RecipeImage(url: recipe.imageUrl),
                ),
                Positioned(
                  top: AppSpacing.x3,
                  right: AppSpacing.x3,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerLowest,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      tooltip: 'Remover dos favoritos',
                      color: theme.colorScheme.primary,
                      onPressed: () => unawaited(
                        context.read<FavoritesViewModel>().remove(recipe.id),
                      ),
                      icon: const Icon(Icons.favorite),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.x4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Chip(
                    label: Text(category),
                    labelStyle: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                    backgroundColor: theme.colorScheme.primaryFixed,
                    side: BorderSide.none,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.x2,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.x1),
                  Text(
                    recipe.title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyFavorites extends StatelessWidget {
  const _EmptyFavorites();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.x6),
      children: [
        Text(
          'Meus Favoritos',
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: AppSpacing.x2),
        const Text('Nenhum favorito ainda'),
        const SizedBox(height: AppSpacing.x6),
        LoadFeedback(
          title: 'Encontre uma receita para salvar',
          message:
              'Toque no coração de uma receita para encontrá-la aqui depois.',
          icon: Icons.favorite_outline,
          actionLabel: 'Procurar receitas',
          actionIcon: Icons.search,
          onRetry: () => context.go(Routes.search),
        ),
      ],
    );
  }
}
