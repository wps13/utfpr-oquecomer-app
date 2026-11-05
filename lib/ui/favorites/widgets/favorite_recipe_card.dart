import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../domain/models/recipe.dart';
import '../../../routing/routes.dart';
import '../../core/themes/spacing.dart';
import '../../core/ui/recipe_image.dart';
import '../view_models/favorites_viewmodel.dart';

class FavoriteRecipeCard extends StatelessWidget {
  const FavoriteRecipeCard({required this.recipe, super.key});

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
