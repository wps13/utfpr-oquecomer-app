import 'package:flutter/material.dart';

import '../../core/themes/colors.dart';
import '../../core/themes/spacing.dart';

class DetectedIngredients extends StatelessWidget {
  const DetectedIngredients({
    required this.ingredients,
    required this.onRemove,
    super.key,
  });

  final List<String> ingredients;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    if (ingredients.isEmpty) {
      return const Card(
        color: AppColors.secondaryContainer,
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.x3),
          child: Text(
            'Mantenha pelo menos um ingrediente para gerar a receita.',
            style: TextStyle(color: AppColors.onSecondaryContainer),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ingredientes detectados',
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.x2),
        Text(
          'Remova os itens que você não pretende usar.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.x2),
        Wrap(
          spacing: AppSpacing.x2,
          runSpacing: AppSpacing.x2,
          children: [
            for (final ingredient in ingredients)
              InputChip(
                label: Text(ingredient),
                deleteButtonTooltipMessage: 'Remover $ingredient',
                onDeleted: () => onRemove(ingredient),
              ),
          ],
        ),
      ],
    );
  }
}
