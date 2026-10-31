import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../routing/routes.dart';
import '../../core/themes/spacing.dart';
import '../../core/ui/load_feedback.dart';
import '../../core/ui/recipe_card.dart';
import '../../core/view_state.dart';
import '../view_models/catalog_viewmodel.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(context.read<CatalogViewModel>().load());
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<CatalogViewModel>();
    return Scaffold(
      appBar: AppBar(
        title: Text(vm.title),
        leading: BackButton(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(Routes.home);
            }
          },
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: _body(vm),
          ),
        ),
      ),
    );
  }

  Widget _body(CatalogViewModel vm) {
    if (vm.state == ViewState.loading) {
      return const Center(
        child: CircularProgressIndicator(semanticsLabel: 'Carregando receitas'),
      );
    }
    if (vm.state == ViewState.error || vm.recipes.isEmpty) {
      final failed = vm.state == ViewState.error;
      return ListView(
        padding: const EdgeInsets.all(AppSpacing.x5),
        children: [
          LoadFeedback(
            title: failed
                ? 'Não foi possível carregar as receitas'
                : 'Nenhuma receita encontrada',
            message: failed
                ? vm.errorMessage
                : 'Tente consultar o catálogo novamente.',
            icon: failed ? Icons.wifi_off_outlined : Icons.restaurant_menu,
            onRetry: () => unawaited(vm.load()),
          ),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.x4),
      itemCount: vm.recipes.length,
      separatorBuilder: (_, index) => const SizedBox(height: AppSpacing.x4),
      itemBuilder: (context, index) => RecipeCard(
        recipe: vm.recipes[index],
        onTap: () => context.push(Routes.recipeDetails(vm.recipes[index].id)),
      ),
    );
  }
}
