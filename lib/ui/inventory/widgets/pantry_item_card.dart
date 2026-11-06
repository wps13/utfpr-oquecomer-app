import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../domain/models/pantry_item.dart';
import '../view_models/inventory_viewmodel.dart';
import 'remove_pantry_item_dialog.dart';

class PantryItemCard extends StatelessWidget {
  const PantryItemCard({required this.item, super.key});

  final PantryItem item;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.restaurant_outlined)),
        title: Text(item.name),
        subtitle: Text('Escaneado em ${_formatDate(item.scannedAt)}'),
        trailing: IconButton(
          tooltip: 'Remover ${item.name}',
          icon: const Icon(Icons.delete_outline),
          onPressed: () => showRemovePantryItemDialog(
            context,
            item,
            context.read<InventoryViewModel>(),
          ),
        ),
      ),
    );
  }

  static String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';
}
