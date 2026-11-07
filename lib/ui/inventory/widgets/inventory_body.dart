import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/themes/spacing.dart';
import '../../core/ui/load_feedback.dart';
import '../../core/view_state.dart';
import '../view_models/inventory_viewmodel.dart';
import 'empty_inventory.dart';
import 'pantry_item_card.dart';

class InventoryBody extends StatelessWidget {
  const InventoryBody({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<InventoryViewModel>();
    switch (vm.state) {
      case ViewState.loading:
        return const Center(child: CircularProgressIndicator());
      case ViewState.error:
        return LoadFeedback(
          title: 'Não foi possível carregar a despensa',
          message: vm.errorMessage,
          onRetry: () => unawaited(vm.load()),
          icon: Icons.kitchen_outlined,
        );
      case ViewState.success:
        if (vm.items.isEmpty) return const EmptyInventory();
        return ListView(
          padding: const EdgeInsets.all(AppSpacing.x4),
          children: [
            Text(
              'Histórico da despensa inteligente',
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSpacing.x2),
            Text(
              'Alimentos identificados nos seus escaneamentos.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.x5),
            for (final item in vm.items) ...[
              PantryItemCard(item: item),
              if (item != vm.items.last) const SizedBox(height: AppSpacing.x3),
            ],
          ],
        );
    }
  }
}
