import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../routing/routes.dart';
import '../../core/themes/spacing.dart';
import '../../core/ui/load_feedback.dart';
import '../../core/ui/recipe_list.dart';
import '../../core/view_state.dart';
import '../view_models/search_viewmodel.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(context.read<SearchViewModel>().load());
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    context.read<SearchViewModel>().updateQuery('');
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SearchViewModel>();
    final count = vm.recipes.length;
    final resultCount = count == 1 ? '1 receita' : '$count receitas';
    return Scaffold(
      appBar: AppBar(title: const Text('Buscar receitas')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.x4),
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    onChanged: vm.updateQuery,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _focusNode.unfocus(),
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      labelText: 'Nome da receita',
                      hintText: 'Ex.: bolo de cenoura',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: vm.query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Limpar busca',
                              onPressed: _clear,
                              icon: const Icon(Icons.close),
                            ),
                    ),
                  ),
                ),
                if (vm.state == ViewState.success && vm.recipes.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.x4,
                    ),
                    child: Text(resultCount),
                  ),
                Expanded(child: _results(vm)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _results(SearchViewModel vm) {
    if (vm.state == ViewState.loading) {
      return const Center(
        child: CircularProgressIndicator(semanticsLabel: 'Carregando receitas'),
      );
    }
    if (vm.state == ViewState.error) {
      return ListView(
        padding: const EdgeInsets.all(AppSpacing.x5),
        children: [
          LoadFeedback(
            title: 'Não foi possível carregar as receitas',
            message: vm.errorMessage,
            onRetry: () => unawaited(vm.load()),
            icon: Icons.wifi_off_outlined,
          ),
        ],
      );
    }
    if (vm.recipes.isEmpty) {
      if (!vm.hasQuery) {
        return ListView(
          padding: const EdgeInsets.all(AppSpacing.x5),
          children: [
            LoadFeedback(
              title: 'Nenhuma receita encontrada',
              onRetry: () => unawaited(vm.load()),
            ),
          ],
        );
      }
      return ListView(
        padding: const EdgeInsets.all(AppSpacing.x5),
        children: [
          const Icon(Icons.search_off, size: 36),
          const SizedBox(height: AppSpacing.x3),
          const Text('Nenhuma receita encontrada', textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.x2),
          const Text(
            'Tente outro nome ou limpe a busca.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.x4),
          TextButton.icon(
            onPressed: _clear,
            icon: const Icon(Icons.close),
            label: const Text('Limpar busca'),
          ),
        ],
      );
    }
    return RecipeList(
      key: ValueKey(vm.query),
      recipes: vm.recipes,
      onSelected: (recipe) {
        _focusNode.unfocus();
        unawaited(context.push(Routes.recipeDetails(recipe.id)));
      },
    );
  }
}
