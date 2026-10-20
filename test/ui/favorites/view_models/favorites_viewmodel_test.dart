import 'package:flutter_test/flutter_test.dart';
import 'package:o_que_comer_app/domain/models/recipe.dart';
import 'package:o_que_comer_app/ui/core/view_state.dart';
import 'package:o_que_comer_app/ui/favorites/view_models/favorites_viewmodel.dart';

import '../../../../testing/fakes/fake_favorites_repository.dart';

void main() {
  final lasanha = Recipe(
    id: '1',
    title: 'Lasanha',
    ingredients: const ['farinha'],
    steps: const ['Misture'],
    source: RecipeSource.catalog,
  );

  late FakeFavoritesRepository repository;
  late FavoritesViewModel viewModel;
  late List<ViewState> states;

  setUp(() {
    repository = FakeFavoritesRepository([lasanha]);
    viewModel = FavoritesViewModel(repository: repository);
    states = [];
    viewModel.addListener(() => states.add(viewModel.state));
  });

  tearDown(() => viewModel.dispose());

  test('starts in loading state', () {
    expect(viewModel.state, ViewState.loading);
  });

  test('load goes loading -> success with the favorites', () async {
    await viewModel.load();

    expect(viewModel.state, ViewState.success);
    expect(viewModel.favorites, [lasanha]);
    expect(states, [ViewState.success]);
  });

  test('load failure ends in error state with a message', () async {
    repository.error = Exception('falhou');

    await viewModel.load();

    expect(viewModel.state, ViewState.error);
    expect(viewModel.errorMessage, contains('falhou'));
  });

  test('add and remove update the list and notify', () async {
    await viewModel.load();
    await viewModel.add('Risoto');

    expect(viewModel.favorites.map((f) => f.name), ['Lasanha', 'Risoto']);

    await viewModel.remove(lasanha.id);

    expect(viewModel.favorites.map((f) => f.name), ['Risoto']);
    expect(states.last, ViewState.success);
  });

  test('can recover from error by loading again', () async {
    repository.error = Exception('falhou');
    await viewModel.load();

    repository.error = null;
    await viewModel.load();

    expect(viewModel.state, ViewState.success);
    expect(viewModel.errorMessage, isNull);
  });
}
