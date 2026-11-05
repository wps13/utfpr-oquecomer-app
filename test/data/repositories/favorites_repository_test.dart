import 'package:hive_ce/hive.dart';
import 'package:hive_ce_test/hive_ce_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:o_que_comer_app/data/repositories/favorites_repository.dart';
import 'package:o_que_comer_app/data/services/errors/error_reporter.dart';
import 'package:o_que_comer_app/domain/models/recipe.dart';

void main() {
  late Box<dynamic> box;
  late HiveFavoritesRepository repository;

  setUp(() async {
    await setUpTestHive();
    box = await Hive.openBox<dynamic>('favorites');
    repository = HiveFavoritesRepository(
      box: HiveFavoritesBoxAdapter(box),
      errorReporter: const DisabledErrorReporter(),
    );
  });

  tearDown(() async {
    await tearDownTestHive();
  });

  test('salva e lista favoritos do catálogo e da IA', () async {
    await repository.save(
      Recipe(
        id: 'catalog-1',
        title: 'Bolo',
        ingredients: const ['farinha'],
        steps: const ['Misture'],
        source: RecipeSource.catalog,
        favoritedAt: DateTime.utc(2026, 1, 1),
      ),
    );
    await repository.save(
      Recipe(
        id: 'ai-1',
        title: 'Sopa',
        ingredients: const ['água'],
        steps: const ['Ferva'],
        source: RecipeSource.ai,
        favoritedAt: DateTime.utc(2026, 1, 2),
      ),
    );

    final favorites = await repository.getFavorites();

    expect(favorites.map((favorite) => favorite.id), ['ai-1', 'catalog-1']);
    expect(await repository.isFavorite('ai-1'), isTrue);
  });

  test('remove exclui o registro', () async {
    await repository.save(
      Recipe(
        id: '1',
        title: 'Bolo',
        ingredients: const ['farinha'],
        steps: const ['Misture'],
        source: RecipeSource.catalog,
      ),
    );

    await repository.remove('1');

    expect(await repository.getFavorites(), isEmpty);
    expect(await repository.isFavorite('1'), isFalse);
  });

  test('salvar a mesma receita novamente não duplica o registro', () async {
    final recipe = Recipe(
      id: 'ai-1',
      title: 'Sopa',
      ingredients: const ['água'],
      steps: const ['Ferva'],
      source: RecipeSource.ai,
    );

    await repository.save(recipe);
    await repository.save(recipe);

    expect((await repository.getFavorites()).map((favorite) => favorite.id), [
      'ai-1',
    ]);
  });
}
