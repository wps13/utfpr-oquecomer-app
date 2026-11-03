import 'package:flutter/material.dart';

import '../../../domain/models/recipe.dart';
import '../../core/themes/colors.dart';
import '../../core/themes/spacing.dart';

class RecipeErrorCard extends StatelessWidget {
  const RecipeErrorCard({
    required this.message,
    required this.onRetry,
    super.key,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Card(
    color: AppColors.errorContainer,
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.x3),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.onErrorContainer),
          const SizedBox(width: AppSpacing.x2),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.onErrorContainer),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Tentar')),
        ],
      ),
    ),
  );
}

class RecipeResultCard extends StatelessWidget {
  const RecipeResultCard({
    required this.recipe,
    this.showFavorite = false,
    this.isFavorite = false,
    this.onFavorite,
    super.key,
  });

  final Recipe recipe;
  final bool showFavorite;
  final bool isFavorite;
  final VoidCallback? onFavorite;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            recipe.title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (showFavorite) ...[
            const SizedBox(height: AppSpacing.x2),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: onFavorite,
                icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border),
                label: Text(isFavorite ? 'Favoritada' : 'Favoritar receita'),
              ),
            ),
          ],
          if (recipe.description.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.x2),
            Text(recipe.description),
          ],
          const SizedBox(height: AppSpacing.x2),
          Text(
            '${recipe.servings} ${recipe.servings == 1 ? 'pessoa' : 'pessoas'}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.x4),
          Text(
            'Ingredientes',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          ...recipe.ingredients.map(
            (ingredient) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              minVerticalPadding: 0,
              visualDensity: const VisualDensity(vertical: -2),
              leading: const Icon(Icons.circle, size: 8),
              title: Text(
                ingredient,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.x3),
          Text(
            'Modo de preparo',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          ...recipe.steps.indexed.map(
            (entry) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                radius: 14,
                backgroundColor: AppColors.primaryFixed,
                child: Text('${entry.$1 + 1}'),
              ),
              title: Text(entry.$2),
            ),
          ),
        ],
      ),
    ),
  );
}
