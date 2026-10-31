import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../domain/models/recipe_category.dart';
import '../../../routing/routes.dart';
import '../../core/themes/radius.dart';
import '../../core/themes/spacing.dart';
import '../../core/ui/load_feedback.dart';
import '../../core/ui/recipe_card.dart';
import '../../core/view_state.dart';
import '../../favorites/view_models/favorites_viewmodel.dart';
import '../view_models/home_viewmodel.dart';
import 'generate_recipe_ai_button.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(context.read<HomeViewModel>().load());
      unawaited(context.read<FavoritesViewModel>().load());
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'O Que Comer',
          style: theme.textTheme.headlineSmall?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.x4),
              children: [
                const _FavoritesPreview(),
                const SizedBox(height: AppSpacing.x4),
                const GenerateRecipeAiButton(),
                const SizedBox(height: AppSpacing.x5),
                Text(
                  'Categorias',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.x4),
                const _Categories(),
                const SizedBox(height: AppSpacing.x4),
                TextButton.icon(
                  onPressed: () => context.push(Routes.catalog),
                  icon: const Icon(Icons.restaurant_menu),
                  label: const Text('Ver todo o catálogo'),
                ),
                TextButton.icon(
                  onPressed: () => context.go(Routes.inventory),
                  icon: const Icon(Icons.kitchen_outlined),
                  label: const Text('Minha despensa'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FavoritesPreview extends StatelessWidget {
  const _FavoritesPreview();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<FavoritesViewModel>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Favoritas',
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            TextButton(
              onPressed: () => context.go(Routes.favorites),
              child: const Text('Ver mais'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.x2),
        if (vm.state == ViewState.loading)
          const Padding(
            padding: EdgeInsets.all(AppSpacing.x4),
            child: Center(
              child: CircularProgressIndicator(
                semanticsLabel: 'Carregando favoritas',
              ),
            ),
          )
        else if (vm.state == ViewState.error)
          LoadFeedback(
            title: 'Não foi possível carregar suas favoritas',
            onRetry: () => unawaited(vm.load()),
            icon: Icons.favorite_outline,
          )
        else if (vm.favorites.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.x5),
              child: Column(
                children: [
                  Icon(
                    Icons.favorite_outline,
                    size: 32,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: AppSpacing.x2),
                  const Text(
                    'Suas receitas favoritas aparecerão aqui.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
        else
          RecipeCard(
            recipe: vm.favorites.first,
            onTap: () =>
                context.push(Routes.recipeDetails(vm.favorites.first.id)),
          ),
      ],
    );
  }
}

class _Categories extends StatelessWidget {
  const _Categories();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<HomeViewModel>();
    if (vm.state == ViewState.loading) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.x6),
        child: Center(
          child: CircularProgressIndicator(
            semanticsLabel: 'Carregando categorias',
          ),
        ),
      );
    }
    if (vm.state == ViewState.error) {
      return LoadFeedback(
        title: 'Não foi possível carregar as categorias',
        message: vm.errorMessage,
        onRetry: () => unawaited(vm.load()),
        icon: Icons.wifi_off_outlined,
      );
    }
    if (vm.categories.isEmpty) {
      return LoadFeedback(
        title: 'Nenhuma categoria disponível no momento',
        onRetry: () => unawaited(vm.load()),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = ((constraints.maxWidth - AppSpacing.x3 * 2) / 3).clamp(
          80.0,
          140.0,
        );
        return Wrap(
          spacing: AppSpacing.x3,
          runSpacing: AppSpacing.x3,
          children: [
            for (final category in vm.categories)
              SizedBox(
                width: width,
                child: _CategoryTile(category: category),
              ),
          ],
        );
      },
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.category});

  final RecipeCategory category;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (icon, background, foreground) = switch (category.id) {
      'doce' => (
        Icons.icecream_outlined,
        scheme.errorContainer,
        scheme.onErrorContainer,
      ),
      'salgado' => (
        Icons.restaurant,
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
      ),
      'agridoce' => (
        Icons.spa_outlined,
        scheme.tertiaryFixedDim,
        scheme.onTertiaryFixed,
      ),
      _ => (
        Icons.restaurant_menu,
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
      ),
    };
    return Semantics(
      button: true,
      label: 'Categoria ${category.label}',
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: AppRadius.borderXl,
          onTap: () => context.push(Routes.catalogByCategory(category.id)),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.x2,
              vertical: AppSpacing.x4,
            ),
            child: Column(
              children: [
                CircleAvatar(
                  backgroundColor: background,
                  foregroundColor: foreground,
                  child: Icon(icon),
                ),
                const SizedBox(height: AppSpacing.x2),
                Text(
                  category.label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
