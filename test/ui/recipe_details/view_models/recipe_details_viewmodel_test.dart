import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:o_que_comer_app/domain/errors/app_failure.dart';
import 'package:o_que_comer_app/domain/models/recipe.dart';
import 'package:o_que_comer_app/ui/core/view_state.dart';
import 'package:o_que_comer_app/ui/recipe_details/view_models/recipe_details_viewmodel.dart';

import '../../../../testing/fakes/fake_catalog_repository.dart';
import '../../../../testing/fakes/fake_favorites_repository.dart';

Recipe _recipe(String id, {RecipeSource source = RecipeSource.catalog}) =>
    Recipe(
      id: id,
      title: 'Lasanha à bolonhesa',
      ingredients: ['Massa', 'Carne moída'],
      steps: ['Cozinhe a carne.', 'Monte as camadas.'],
      source: source,
      preparationMinutes: 45,
      servings: 4,
    );

void main() {
  late FakeCatalogRepository catalog;
  late FakeFavoritesRepository favorites;
  late List<ViewState> states;

  RecipeDetailsViewModel build(String id) {
    final vm = RecipeDetailsViewModel(
      recipeId: id,
      catalogRepository: catalog,
      favoritesRepository: favorites,
    );
    vm.addListener(() => states.add(vm.state));
    addTearDown(vm.dispose);
    return vm;
  }

  setUp(() {
    catalog = FakeCatalogRepository()..recipes = [_recipe('1')];
    favorites = FakeFavoritesRepository();
    states = [];
  });

  test('starts loading and loads the recipe from the catalog', () async {
    final vm = build('1');
    expect(vm.state, ViewState.loading);

    await vm.load();

    expect(vm.state, ViewState.success);
    expect(vm.recipe, _recipe('1'));
    expect(catalog.requestedRecipes, ['1']);
    expect(states, [ViewState.success]);
  });

  test('falls back to the saved favorite when the catalog fails', () async {
    catalog.loadRecipe = (_) async => throw const NoConnectionFailure();
    favorites.items.add(_recipe('1'));
    final vm = build('1');

    await vm.load();

    expect(vm.state, ViewState.success);
    expect(vm.recipe?.id, '1');
  });

  test('opens AI recipes saved as favorites', () async {
    final aiRecipe = _recipe('ai-123', source: RecipeSource.ai);
    favorites.items.add(aiRecipe);
    final vm = build('ai-123');

    await vm.load();

    expect(vm.state, ViewState.success);
    expect(vm.recipe, aiRecipe);
  });

  test('shows the catalog error when there is no fallback', () async {
    catalog.loadRecipe = (_) async => throw const NoConnectionFailure();
    final vm = build('1');

    await vm.load();

    expect(vm.state, ViewState.error);
    expect(vm.recipe, isNull);
    expect(vm.errorMessage, 'Sem conexão com a internet');
  });

  test('uses a generic message for unexpected errors', () async {
    catalog.loadRecipe = (_) async => throw StateError('boom');
    favorites.error = Exception('sem favoritos');
    final vm = build('1');

    await vm.load();

    expect(vm.state, ViewState.error);
    expect(vm.errorMessage, 'Tente novamente em instantes.');
  });

  test('retry goes back to loading and recovers', () async {
    var fail = true;
    catalog.loadRecipe = (id) async {
      if (fail) throw const TimeoutFailure();
      return _recipe(id);
    };
    final vm = build('1');
    await vm.load();
    expect(vm.state, ViewState.error);

    fail = false;
    await vm.load();

    expect(states, [ViewState.error, ViewState.loading, ViewState.success]);
    expect(vm.errorMessage, isNull);
  });

  test('ignores a stale response when load is called again', () async {
    final first = Completer<Recipe>();
    var calls = 0;
    catalog.loadRecipe = (id) {
      calls++;
      return calls == 1 ? first.future : Future.value(_recipe(id));
    };
    final vm = build('1');

    final stale = vm.load();
    await vm.load();
    first.completeError(const TimeoutFailure());
    await stale;

    expect(vm.state, ViewState.success);
  });

  test('does not notify after dispose', () async {
    final pending = Completer<Recipe>();
    catalog.loadRecipe = (_) => pending.future;
    final vm = RecipeDetailsViewModel(
      recipeId: '1',
      catalogRepository: catalog,
      favoritesRepository: favorites,
    );

    final load = vm.load();
    vm.dispose();
    pending.complete(_recipe('1'));

    await expectLater(load, completes);
  });
}
