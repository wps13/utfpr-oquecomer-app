import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:o_que_comer_app/domain/errors/app_failure.dart';
import 'package:o_que_comer_app/domain/models/recipe.dart';
import 'package:o_que_comer_app/domain/models/recipe_category.dart';
import 'package:o_que_comer_app/ui/catalog/view_models/catalog_viewmodel.dart';
import 'package:o_que_comer_app/ui/core/view_state.dart';

import '../../../../testing/fakes/fake_catalog_repository.dart';

Recipe _recipe(String id) => Recipe(
  id: id,
  title: 'Bolo',
  ingredients: ['Farinha'],
  steps: ['Asse.'],
  source: RecipeSource.catalog,
  type: 'doce',
);

void main() {
  late FakeCatalogRepository repository;
  late CatalogViewModel vm;

  setUp(() {
    repository = FakeCatalogRepository()..recipes = [_recipe('1')];
    vm = CatalogViewModel(
      repository: repository,
      category: const RecipeCategory('doce'),
    );
  });
  tearDown(() => vm.dispose());

  test('consulta somente a categoria selecionada', () async {
    await vm.load();
    expect(repository.requestedCategories, ['doce']);
    expect(repository.listCalls, 0);
    expect(vm.title, 'Doce');
    expect(vm.state, ViewState.success);
    expect(vm.recipes.single.id, '1');
  });

  test('receitas vazias são sucesso e não erro', () async {
    repository.recipes = [];
    await vm.load();
    expect(vm.state, ViewState.success);
    expect(vm.recipes, isEmpty);
    expect(vm.errorMessage, isNull);
  });

  test('timeout pode ser recuperado por uma nova tentativa', () async {
    repository.loadRecipes = (_) async => throw const TimeoutFailure();
    await vm.load();
    expect(vm.state, ViewState.error);
    expect(vm.errorMessage, const TimeoutFailure().message);
    repository.loadRecipes = null;
    await vm.load();
    expect(vm.state, ViewState.success);
    expect(vm.errorMessage, isNull);
    expect(repository.requestedCategories, ['doce', 'doce']);
  });

  test('a rota de catálogo sem categoria continua disponível', () async {
    final all = CatalogViewModel(repository: repository);
    addTearDown(all.dispose);
    await all.load();
    expect(all.title, 'Catálogo');
    expect(all.recipes, hasLength(1));
    expect(repository.listCalls, 1);
  });

  test('sair da tela enquanto carrega não causa erro de notificação', () async {
    final pending = Completer<List<Recipe>>();
    repository.loadRecipes = (_) => pending.future;
    final disposedVm = CatalogViewModel(
      repository: repository,
      category: const RecipeCategory('doce'),
    );
    final loading = disposedVm.load();
    disposedVm.dispose();
    pending.complete([_recipe('1')]);
    await expectLater(loading, completes);
  });
}
