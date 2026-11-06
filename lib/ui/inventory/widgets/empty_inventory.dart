import 'package:flutter/material.dart';

import '../../core/themes/spacing.dart';

class EmptyInventory extends StatelessWidget {
  const EmptyInventory({super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(AppSpacing.x6),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.kitchen_outlined,
          size: 40,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: AppSpacing.x3),
        Text(
          'Sua despensa está vazia',
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.x2),
        const Text(
          'Os alimentos detectados em novos escaneamentos aparecerão aqui.',
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}
