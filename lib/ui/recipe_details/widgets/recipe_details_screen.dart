import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../domain/models/recipe.dart';
import '../../../routing/routes.dart';
import '../../core/themes/spacing.dart';
import '../../core/ui/load_feedback.dart';
import '../../core/ui/recipe_image.dart';
import '../../core/view_state.dart';
import '../../favorites/view_models/favorites_viewmodel.dart';
import '../view_models/recipe_details_viewmodel.dart';
import 'hands_free_card.dart';
import 'ingredients_checklist.dart';
import 'preparation_steps.dart';

/// Largura a partir da qual ingredientes vão para uma coluna lateral.
const _wideLayoutBreakpoint = 840.0;

class RecipeDetailsScreen extends StatefulWidget {
  const RecipeDetailsScreen({super.key});

  @override
  State<RecipeDetailsScreen> createState() => _RecipeDetailsScreenState();
}

class _RecipeDetailsScreenState extends State<RecipeDetailsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(context.read<RecipeDetailsViewModel>().load());
      // Garante o estado do botão de favoritar ao abrir por link direto.
      final favorites = context.read<FavoritesViewModel>();
      if (favorites.state != ViewState.success) unawaited(favorites.load());
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<RecipeDetailsViewModel>();
    final recipe = vm.recipe;

    if (vm.state == ViewState.success && recipe != null) {
      return Scaffold(
        body: _RecipeContent(
          recipe: recipe,
          ingredients: vm.ingredients,
          steps: vm.steps,
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalhes da receita'),
        leading: const _BackToPrevious(),
      ),
      body: Center(
        child: vm.state == ViewState.error
            ? Padding(
                padding: const EdgeInsets.all(AppSpacing.x4),
                child: LoadFeedback(
                  title: 'Não foi possível carregar a receita',
                  message: vm.errorMessage,
                  onRetry: () => unawaited(vm.load()),
                  icon: Icons.wifi_off_outlined,
                ),
              )
            : const CircularProgressIndicator(
                semanticsLabel: 'Carregando receita',
              ),
      ),
    );
  }
}

/// Altura da foto no topo; o título só aparece quando ela recolhe.
const _headerHeight = 280.0;

class _RecipeContent extends StatefulWidget {
  const _RecipeContent({
    required this.recipe,
    required this.ingredients,
    required this.steps,
  });

  final Recipe recipe;
  final List<String> ingredients;
  final List<String> steps;

  @override
  State<_RecipeContent> createState() => _RecipeContentState();
}

class _RecipeContentState extends State<_RecipeContent> {
  final _scroll = ScrollController();
  bool _collapsed = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  // Estado efêmero de UI: mostrar o título só sobre o fundo liso, não na foto.
  void _onScroll() {
    final collapsed = _scroll.offset > _headerHeight - kToolbarHeight * 2;
    if (collapsed != _collapsed) setState(() => _collapsed = collapsed);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recipe = widget.recipe;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final summary = <Widget>[
      Text(
        recipe.title,
        style: theme.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      if (recipe.description.isNotEmpty) ...[
        const SizedBox(height: AppSpacing.x2),
        Text(
          recipe.description,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
      const SizedBox(height: AppSpacing.x3),
      Wrap(
        spacing: AppSpacing.x5,
        runSpacing: AppSpacing.x2,
        children: [
          _MetaItem(
            icon: Icons.schedule,
            label: recipe.preparationMinutes == null
                ? 'Tempo não informado'
                : '${recipe.preparationMinutes} min',
          ),
          _MetaItem(
            icon: Icons.people_outline,
            label: recipe.servings == 1
                ? '1 porção'
                : '${recipe.servings} porções',
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.x5),
      HandsFreeCard(
        onStart: () => unawaited(context.push(Routes.handsFreeMode(recipe.id))),
      ),
    ];
    final ingredients = IngredientsChecklist(ingredients: widget.ingredients);
    final steps = PreparationSteps(steps: widget.steps);

    return CustomScrollView(
      controller: _scroll,
      slivers: [
        SliverAppBar(
          pinned: true,
          expandedHeight: _headerHeight,
          leading: const _BackToPrevious(),
          title: AnimatedOpacity(
            opacity: _collapsed ? 1 : 0,
            duration: const Duration(milliseconds: 150),
            child: Text(
              recipe.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          actions: [_FavoriteButton(recipe: recipe)],
          flexibleSpace: FlexibleSpaceBar(
            background: RecipeImage(url: recipe.imageUrl, iconSize: 64),
          ),
        ),
        SliverSafeArea(
          top: false,
          sliver: SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.x4),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth >= _wideLayoutBreakpoint) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 7,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  ...summary,
                                  const SizedBox(height: AppSpacing.x8),
                                  steps,
                                ],
                              ),
                            ),
                            const SizedBox(width: AppSpacing.x6),
                            Expanded(flex: 5, child: ingredients),
                          ],
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ...summary,
                          const SizedBox(height: AppSpacing.x6),
                          ingredients,
                          const SizedBox(height: AppSpacing.x8),
                          steps,
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MetaItem extends StatelessWidget {
  const _MetaItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: AppSpacing.x1),
        Flexible(
          child: Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

/// Fundo claro para os botões continuarem legíveis sobre a foto.
class _OverlayButton extends StatelessWidget {
  const _OverlayButton({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(AppSpacing.x1),
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        shape: BoxShape.circle,
      ),
      child: child,
    ),
  );
}

class _BackToPrevious extends StatelessWidget {
  const _BackToPrevious();

  @override
  Widget build(BuildContext context) => _OverlayButton(
    child: BackButton(
      onPressed: () {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go(Routes.home);
        }
      },
    ),
  );
}

class _FavoriteButton extends StatelessWidget {
  const _FavoriteButton({required this.recipe});

  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    final favorites = context.watch<FavoritesViewModel>();
    final isFavorite = favorites.favorites.any((f) => f.id == recipe.id);
    final busy = favorites.state == ViewState.loading;

    return _OverlayButton(
      child: IconButton(
        tooltip: isFavorite ? 'Remover dos favoritos' : 'Favoritar',
        isSelected: isFavorite,
        onPressed: busy
            ? null
            : () => unawaited(
                isFavorite
                    ? favorites.remove(recipe.id)
                    : favorites.saveRecipe(recipe),
              ),
        color: Theme.of(context).colorScheme.primary,
        icon: const Icon(Icons.favorite_border),
        selectedIcon: const Icon(Icons.favorite),
      ),
    );
  }
}
