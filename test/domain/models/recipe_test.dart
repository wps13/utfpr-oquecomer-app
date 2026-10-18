import 'package:flutter_test/flutter_test.dart';
import 'package:o_que_comer_app/domain/models/recipe.dart';

void main() {
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
