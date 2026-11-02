import 'package:flutter/material.dart';

import '../../core/themes/spacing.dart';

/// Modo de preparo em passos numerados, um bloco por passo.
class PreparationSteps extends StatelessWidget {
  const PreparationSteps({required this.steps, super.key});

  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Modo de preparo',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.x4),
        for (final (index, step) in steps.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.x5),
            child: Semantics(
              label: 'Passo ${index + 1}',
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    foregroundColor: theme.colorScheme.onPrimaryContainer,
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.x3),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.x1),
                      child: Text(step, style: theme.textTheme.bodyLarge),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
