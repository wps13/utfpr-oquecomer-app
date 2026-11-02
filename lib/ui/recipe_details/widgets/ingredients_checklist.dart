import 'package:flutter/material.dart';

import '../../core/themes/radius.dart';
import '../../core/themes/spacing.dart';

/// Lista de ingredientes com marcação local (estado efêmero de UI): o item
/// marcado fica riscado e esmaecido para o usuário acompanhar o preparo.
class IngredientsChecklist extends StatefulWidget {
  const IngredientsChecklist({required this.ingredients, super.key});

  final List<String> ingredients;

  @override
  State<IngredientsChecklist> createState() => _IngredientsChecklistState();
}

class _IngredientsChecklistState extends State<IngredientsChecklist> {
  final _checked = <int>{};

  void _toggle(int index) => setState(() {
    if (!_checked.remove(index)) _checked.add(index);
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.borderXl,
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.x4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
              child: Text(
                'Ingredientes',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.x2),
            for (final (index, ingredient) in widget.ingredients.indexed)
              CheckboxListTile(
                value: _checked.contains(index),
                onChanged: (_) => _toggle(index),
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
                visualDensity: VisualDensity.compact,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.x2,
                ),
                title: Text(
                  ingredient,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    decoration: _checked.contains(index)
                        ? TextDecoration.lineThrough
                        : null,
                    color: _checked.contains(index)
                        ? theme.colorScheme.onSurfaceVariant
                        : theme.colorScheme.onSurface,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
