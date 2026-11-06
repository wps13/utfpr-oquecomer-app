import 'package:flutter/material.dart';

import '../../../domain/models/pantry_item.dart';
import '../view_models/inventory_viewmodel.dart';

Future<void> showRemovePantryItemDialog(
  BuildContext context,
  PantryItem item,
  InventoryViewModel viewModel,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Remover alimento?'),
      content: Text('Deseja remover "${item.name}" da sua despensa?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Remover'),
        ),
      ],
    ),
  );
  if (confirmed == true && context.mounted) {
    await viewModel.remove(item.id);
  }
}
