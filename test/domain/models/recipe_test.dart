import 'package:flutter_test/flutter_test.dart';
import 'package:o_que_comer_app/domain/models/recipe.dart';

void main() {
  test(
    'tempo ausente no catálogo continua ausente ao favoritar e restaurar',
    () {
      final recipe = Recipe(
        id: '1',
        title: 'Bolo',
        ingredients: ['Farinha'],
        steps: ['Asse.'],
        source: RecipeSource.catalog,
        preparationMinutes: null,
      );
      final saved = recipe.copyWithFavoritedAt(DateTime.utc(2026, 10, 30));
      expect(saved.preparationMinutes, isNull);
      expect(Recipe.fromJson(saved.toJson()), saved);
    },
  );

  test('receita do catálogo usa o mesmo contrato serializável da IA', () {
    final ingredients = ['2 ovos'];
    final recipe = Recipe(
      id: 'catalog_1',
      title: 'Omelete',
      description: 'Omelete simples.',
      ingredients: ingredients,
      steps: ['Bata os ovos e cozinhe.'],
      preparationMinutes: 10,
      servings: 1,
      source: RecipeSource.catalog,
    );
    ingredients.clear();
    expect(recipe.ingredients, ['2 ovos']);
    expect(Recipe.fromJson(recipe.toJson()).toJson(), recipe.toJson());
  });
}
