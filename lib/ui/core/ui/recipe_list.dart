import 'package:flutter/material.dart';

import '../../../domain/models/recipe.dart';
import '../themes/spacing.dart';
import 'recipe_card.dart';

/// Estrutura compartilhada pelas listagens de categoria e busca por nome.
class RecipeList extends StatelessWidget {
  const RecipeList({
    required this.recipes,
    required this.onSelected,
    super.key,
  });

  final List<Recipe> recipes;
  final ValueChanged<Recipe> onSelected;

  @override
  Widget build(BuildContext context) => ListView.separated(
    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
    padding: const EdgeInsets.all(AppSpacing.x4),
    itemCount: recipes.length,
    separatorBuilder: (_, index) => const SizedBox(height: AppSpacing.x4),
    itemBuilder: (_, index) => RecipeCard(
      recipe: recipes[index],
      onTap: () => onSelected(recipes[index]),
    ),
  );
}
