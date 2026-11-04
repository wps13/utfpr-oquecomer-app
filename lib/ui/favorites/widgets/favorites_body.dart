import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/themes/spacing.dart';
import '../../core/view_state.dart';
import '../view_models/favorites_viewmodel.dart';
import 'empty_favorites.dart';
import 'favorite_recipe_card.dart';

class FavoritesBody extends StatelessWidget {
  const FavoritesBody({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<FavoritesViewModel>();
    switch (vm.state) {
      case ViewState.loading:
        return const Center(child: CircularProgressIndicator());
      case ViewState.error:
        return _FavoritesError(message: vm.errorMessage);
      case ViewState.success:
        if (vm.favorites.isEmpty) return const EmptyFavorites();
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
              FavoriteRecipeCard(recipe: favorite),
              if (favorite != vm.favorites.last)
                const SizedBox(height: AppSpacing.x4),
            ],
          ],
        );
    }
  }
}

class _FavoritesError extends StatelessWidget {
  const _FavoritesError({required this.message});

  final String? message;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Erro: $message'),
        const SizedBox(height: AppSpacing.x2),
        FilledButton(
          onPressed: context.read<FavoritesViewModel>().load,
          child: const Text('Tentar novamente'),
        ),
      ],
    ),
  );
}
