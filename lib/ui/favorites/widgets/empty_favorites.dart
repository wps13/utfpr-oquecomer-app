import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../routing/routes.dart';
import '../../core/themes/spacing.dart';
import '../../core/ui/load_feedback.dart';

class EmptyFavorites extends StatelessWidget {
  const EmptyFavorites({super.key});

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(AppSpacing.x6),
    children: [
      Text(
        'Meus Favoritos',
        style: Theme.of(context).textTheme.headlineSmall
            ?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: AppSpacing.x2),
      const Text('Nenhum favorito ainda'),
      const SizedBox(height: AppSpacing.x6),
      LoadFeedback(
        title: 'Encontre uma receita para salvar',
        message:
            'Toque no coração de uma receita para encontrá-la aqui depois.',
        icon: Icons.favorite_outline,
        actionLabel: 'Procurar receitas',
        actionIcon: Icons.search,
        onRetry: () => context.go(Routes.search),
      ),
    ],
  );
}
