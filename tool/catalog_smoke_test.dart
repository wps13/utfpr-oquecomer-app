// Execução manual: flutter test tool/catalog_smoke_test.dart
// Opcional: --dart-define=CATALOG_BASE_URL=https://api-receitas-pi.vercel.app
import 'package:flutter_test/flutter_test.dart';
import 'package:o_que_comer_app/config/env.dart';
import 'package:o_que_comer_app/data/repositories/api_catalog_repository.dart';
import 'package:o_que_comer_app/data/services/api/api_client.dart';
import 'package:o_que_comer_app/data/services/errors/error_reporter.dart';
import 'package:o_que_comer_app/data/services/errors/http_error_reporter.dart';
import 'package:o_que_comer_app/domain/models/recipe.dart';

void main() {
  late ApiCatalogRepository repository;

  setUp(() {
    const reporter = DisabledErrorReporter();
    final client = CatalogApiClient(
      Env.fromEnvironment(),
      const HttpErrorReporter(errorReporter: reporter),
      enableLogs: false,
    );
    addTearDown(client.close);
    repository = ApiCatalogRepository(client: client, errorReporter: reporter);
  });

  test(
    'API real lista, detalha e busca uma receita pelo nome e ingrediente',
    () async {
      final recipes = await repository.listRecipes(limit: 2);
      expect(recipes, isNotEmpty);
      final recipe = await repository.getRecipe(recipes.first.id);
      expect(recipe.source, RecipeSource.catalog);
      expect(recipe.ingredients.single, isNotEmpty);
      expect(recipe.steps.single, isNotEmpty);
      expect(Recipe.fromJson(recipe.toJson()), recipe);

      final byName = await repository.searchByName(recipe.title);
      expect(byName.any((item) => item.id == recipe.id), isTrue);

      expect(recipe.baseIngredients, isNotEmpty);
      final byIngredient = await repository.searchByIngredient(
        recipe.baseIngredients.first,
      );
      expect(byIngredient.any((item) => item.id == recipe.id), isTrue);

      final empty = await repository.searchByName('zzzzzzapp24semresultado');
      expect(empty, isEmpty);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
