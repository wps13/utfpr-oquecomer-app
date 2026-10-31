import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:o_que_comer_app/data/repositories/ai_repository.dart';
import 'package:o_que_comer_app/domain/models/recipe.dart';
import 'package:o_que_comer_app/ui/ai_recipes/view_models/ai_recipes_viewmodel.dart';

class _FakeAiRepository implements AiRepository {
  List<String> foods = ['tomate', 'ovo', 'cebola'];
  List<String>? generatedWith;
  int? generatedServings;
  String? generatedLocation;

  @override
  Future<List<String>> identifyFoods({
    required Uint8List imageBytes,
    required String mimeType,
  }) async => foods;

  @override
  Future<Recipe> generateRecipe(
    List<String> ingredients, {
    int servings = 2,
    String? location,
  }) async {
    generatedWith = ingredients;
    generatedServings = servings;
    generatedLocation = location;
    return Recipe(
      id: 'ai_test',
      title: 'Receita teste',
      description: '',
      ingredients: ingredients,
      steps: const ['Misture e cozinhe.'],
      preparationMinutes: 10,
      servings: servings,
      source: RecipeSource.ai,
    );
  }
}

void main() {
  test(
    'remove ingredientes antes de gerar e envia apenas os restantes',
    () async {
      final repository = _FakeAiRepository();
      final viewModel = AiRecipesViewModel(repository: repository);
      viewModel.setImage(
        bytes: Uint8List.fromList([1]),
        mimeType: 'image/jpeg',
      );

      await viewModel.generateRecipe();
      expect(viewModel.detectedIngredients, ['tomate', 'ovo', 'cebola']);
      expect(repository.generatedWith, isNull);

      viewModel.removeIngredient('ovo');
      await viewModel.generateRecipe();

      expect(repository.generatedWith, ['tomate', 'cebola']);
      expect(repository.generatedServings, AiRecipesViewModel.defaultServings);
    },
  );

  test('envia a quantidade de pessoas escolhida', () async {
    final repository = _FakeAiRepository();
    final viewModel = AiRecipesViewModel(repository: repository);
    viewModel.setImage(bytes: Uint8List.fromList([1]), mimeType: 'image/jpeg');
    viewModel.setServings(5);

    await viewModel.generateRecipe();
    await viewModel.generateRecipe();

    expect(repository.generatedServings, 5);
    expect(viewModel.recipe?.servings, 5);
  });

  test('envia a localização regional selecionada', () async {
    final repository = _FakeAiRepository();
    final viewModel = AiRecipesViewModel(repository: repository);
    viewModel.setImage(bytes: Uint8List.fromList([1]), mimeType: 'image/jpeg');
    viewModel.setLocation('Curitiba, PR');

    await viewModel.generateRecipe();
    await viewModel.generateRecipe();

    expect(repository.generatedLocation, 'Curitiba, PR');
  });

  test('ignora quantidade de pessoas menor que o mínimo', () {
    final viewModel = AiRecipesViewModel(repository: _FakeAiRepository());

    viewModel.setServings(AiRecipesViewModel.minServings - 1);
    expect(viewModel.servings, AiRecipesViewModel.defaultServings);
    viewModel.setServings(100);
    expect(viewModel.servings, 100);
  });

  test(
    'desabilita a geração quando todos os ingredientes são removidos',
    () async {
      final repository = _FakeAiRepository();
      final viewModel = AiRecipesViewModel(repository: repository);
      viewModel.setImage(
        bytes: Uint8List.fromList([1]),
        mimeType: 'image/jpeg',
      );

      await viewModel.generateRecipe();
      for (final ingredient in [...viewModel.detectedIngredients]) {
        viewModel.removeIngredient(ingredient);
      }

      expect(viewModel.detectedIngredients, isEmpty);
      expect(viewModel.canGenerateRecipe, isFalse);
      await viewModel.generateRecipe();
      expect(repository.generatedWith, isNull);
    },
  );
}
