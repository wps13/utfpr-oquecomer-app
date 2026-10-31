import 'package:flutter_test/flutter_test.dart';
import 'package:o_que_comer_app/data/model/catalog_recipe_dto.dart';
import 'package:o_que_comer_app/domain/models/recipe.dart';

Map<String, Object?> _payload() => {
  'id': 7,
  'receita': ' Bolo de cenoura ',
  'ingredientes': '1,5 xícara de farinha; 2 cenouras',
  'modo_preparo': 'Misture.\nAsse por 40 minutos.',
  'IngredientesBase': [
    {
      'nomesIngrediente': ['cenoura', 'farinha'],
    },
    {
      'nomesIngrediente': ['ovos'],
    },
  ],
};

void main() {
  test('converte ingredientes base aninhados e preserva o texto completo', () {
    final recipe = CatalogRecipeDto.fromJson(_payload()).toRecipe();
    expect(recipe.id, '7');
    expect(recipe.title, 'Bolo de cenoura');
    expect(recipe.source, RecipeSource.catalog);
    expect(recipe.ingredients, ['1,5 xícara de farinha; 2 cenouras']);
    expect(recipe.steps, ['Misture.\nAsse por 40 minutos.']);
    expect(recipe.baseIngredients, ['cenoura', 'farinha', 'ovos']);
    expect(Recipe.fromJson(recipe.toJson()), recipe);
    expect(() => recipe.baseIngredients.add('outro'), throwsUnsupportedError);
  });

  test('campos opcionais ausentes não impedem a receita', () {
    final payload = _payload()..remove('IngredientesBase');
    final recipe = CatalogRecipeDto.fromJson(payload).toRecipe();
    expect(recipe.baseIngredients, isEmpty);
    expect(recipe.createdAt, isNull);
    expect(recipe.imageUrl, isNull);
    expect(recipe.type, isNull);
  });

  for (final changes in <Map<String, Object?>>[
    {'id': null},
    {'id': '7'},
    {'receita': ''},
    {'ingredientes': null},
    {'modo_preparo': []},
    {'created_at': 'data inválida'},
    {'link_imagem': 3},
    {'IngredientesBase': 'cenoura'},
    {
      'IngredientesBase': [
        {
          'nomesIngrediente': [1],
        },
      ],
    },
  ]) {
    test('rejeita campo incompatível: ${changes.keys.single}', () {
      expect(
        () => CatalogRecipeDto.fromJson({..._payload(), ...changes}),
        throwsFormatException,
      );
    });
  }
}
