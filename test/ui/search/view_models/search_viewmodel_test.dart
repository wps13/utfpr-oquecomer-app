import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:o_que_comer_app/domain/errors/app_failure.dart';
import 'package:o_que_comer_app/domain/models/recipe.dart';
import 'package:o_que_comer_app/ui/core/view_state.dart';
import 'package:o_que_comer_app/ui/search/view_models/search_viewmodel.dart';

import '../../../../testing/fakes/fake_catalog_repository.dart';

Recipe _recipe(String id, String name) => Recipe(
  id: id,
  title: name,
  ingredients: ['limão'],
  steps: ['Prepare.'],
  source: RecipeSource.catalog,
  preparationMinutes: null,
);

void main() {
  late FakeCatalogRepository repository;
  late SearchViewModel vm;

  setUp(() {
    repository = FakeCatalogRepository()
      ..recipes = [
        _recipe('1', 'Frango grelhado'),
        _recipe('2', 'Torta de Limão'),
        _recipe('3', 'Pão de Açúcar'),
        _recipe('4', 'Panqueca'),
      ];
    vm = SearchViewModel(repository: repository);
  });
  tearDown(() => vm.dispose());

  test('carrega a listagem original sem filtro e protege a lista', () async {
    expect(vm.state, ViewState.loading);
    await vm.load();
    expect(vm.state, ViewState.success);
    expect(vm.recipes, repository.recipes);
    expect(() => vm.recipes.clear(), throwsUnsupportedError);
  });

  for (final query in ['limao', 'LIMÃO', 'LiMãO', 'lima\u0303o', ' LIMAO ']) {
    test('busca "$query" encontra somente o nome correspondente', () async {
      await vm.load();
      vm.updateQuery(query);
      expect(vm.recipes.map((recipe) => recipe.id), ['2']);
      expect(vm.query, query);
      expect(repository.allRecipesCalls, 1);
    });
  }

  test('acento na consulta também encontra título sem acento', () async {
    await vm.load();
    vm.updateQuery('PÁNQUECA');
    expect(vm.recipes.single.id, '4');
  });

  test('encontra trecho no meio do nome e ignora os ingredientes', () async {
    await vm.load();
    vm.updateQuery('orta de');
    expect(vm.recipes.single.id, '2');
    vm.updateQuery('limao');
    expect(vm.recipes.map((recipe) => recipe.id), ['2']);
  });

  test('busca sem resultado é sucesso com lista vazia', () async {
    await vm.load();
    vm.updateQuery('zzzzzz');
    expect(vm.state, ViewState.success);
    expect(vm.recipes, isEmpty);
    expect(vm.errorMessage, isNull);
  });

  test(
    'limpar ou digitar espaços restaura a lista e a ordem originais',
    () async {
      await vm.load();
      vm.updateQuery('pao');
      expect(vm.recipes.single.id, '3');
      vm.updateQuery('');
      expect(vm.recipes, repository.recipes);
      vm.updateQuery(' \t ');
      expect(vm.recipes, repository.recipes);
      expect(repository.allRecipesCalls, 1);
    },
  );

  test(
    'texto digitado durante o carregamento é aplicado ao catálogo completo',
    () async {
      final pending = Completer<List<Recipe>>();
      repository.loadAllRecipes = () => pending.future;
      final loading = vm.load();
      vm.updateQuery('frango');
      vm.updateQuery('limao');
      pending.complete(repository.recipes);
      await loading;
      expect(vm.state, ViewState.success);
      expect(vm.recipes.single.id, '2');
    },
  );

  test(
    'falha de conexão permite repetir a carga preservando o texto',
    () async {
      repository.loadAllRecipes = () async => throw const NoConnectionFailure();
      vm.updateQuery('limao');
      await vm.load();
      expect(vm.state, ViewState.error);
      expect(vm.errorMessage, const NoConnectionFailure().message);
      repository.loadAllRecipes = null;
      await vm.load();
      expect(vm.state, ViewState.success);
      expect(vm.query, 'limao');
      expect(vm.recipes.single.id, '2');
      expect(vm.errorMessage, isNull);
    },
  );

  test('catálogo vazio é sucesso', () async {
    repository.recipes = [];
    await vm.load();
    expect(vm.state, ViewState.success);
    expect(vm.recipes, isEmpty);
  });

  test('resposta antiga não sobrescreve uma nova carga', () async {
    final first = Completer<List<Recipe>>();
    repository.loadAllRecipes = () => first.future;
    final loading = vm.load();
    repository.loadAllRecipes = null;
    await vm.load();
    first.complete([_recipe('antiga', 'Receita antiga')]);
    await loading;
    expect(vm.recipes, repository.recipes);
  });

  test('sair durante o carregamento não notifica uma VM descartada', () async {
    final pending = Completer<List<Recipe>>();
    repository.loadAllRecipes = () => pending.future;
    final disposedVm = SearchViewModel(repository: repository);
    final loading = disposedVm.load();
    disposedVm.dispose();
    pending.complete(repository.recipes);
    await expectLater(loading, completes);
  });
}
