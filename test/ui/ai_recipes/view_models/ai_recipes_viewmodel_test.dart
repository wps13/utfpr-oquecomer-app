import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:o_que_comer_app/data/repositories/ai_repository.dart';
import 'package:o_que_comer_app/domain/models/recipe.dart';
import 'package:o_que_comer_app/domain/models/ai_failure.dart';
import 'package:o_que_comer_app/ui/ai_recipes/view_models/ai_recipes_viewmodel.dart';

import '../../../../testing/fakes/fake_pantry_repository.dart';

class _FakeAiRepository implements AiRepository {
  List<String> foods = ['tomate', 'ovo', 'cebola'];
  Exception? identifyError;
  List<String>? generatedWith;
  int? generatedServings;
  String? generatedLocation;

  @override
  Future<List<String>> identifyFoods({
    required Uint8List imageBytes,
    required String mimeType,
  }) async {
    final error = identifyError;
    if (error != null) throw error;
    return foods;
  }

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
  group('despensa', () {
    late _FakeAiRepository repository;
    late FakePantryRepository pantry;
    late AiRecipesViewModel viewModel;

    setUp(() {
      repository = _FakeAiRepository();
      pantry = FakePantryRepository();
      viewModel = AiRecipesViewModel(
        repository: repository,
        pantryRepository: pantry,
      );
      viewModel.setImage(
        bytes: Uint8List.fromList([1]),
        mimeType: 'image/jpeg',
      );
    });

    test('guarda os alimentos detectados após enviar a imagem', () async {
      await viewModel.generateRecipe();

      expect(pantry.scans, [
        ['tomate', 'ovo', 'cebola'],
      ]);
    });

    test(
      'guarda tudo o que foi detectado, mesmo se o usuário remover',
      () async {
        await viewModel.generateRecipe();
        viewModel.removeIngredient('ovo');
        await viewModel.generateRecipe();

        expect(pantry.scans, [
          ['tomate', 'ovo', 'cebola'],
        ]);
      },
    );

    test('gerar a receita não guarda os alimentos de novo', () async {
      await viewModel.generateRecipe();
      await viewModel.generateRecipe();
      await viewModel.generateRecipe();

      expect(pantry.scans, hasLength(1));
    });

    test('um novo escaneamento guarda de novo', () async {
      await viewModel.generateRecipe();
      viewModel.setImage(bytes: Uint8List.fromList([2]), mimeType: 'image/png');
      await viewModel.generateRecipe();

      expect(pantry.scans, hasLength(2));
    });

    test('se o escaneamento falhar, nada é guardado', () async {
      repository.identifyError = const AiFailure(AiFailureKind.connection);

      await viewModel.generateRecipe();

      expect(pantry.scans, isEmpty);
      expect(viewModel.errorMessage, isNotNull);
      expect(viewModel.foodsDetected, isFalse);
    });

    test('se nenhum alimento for detectado, nada é guardado', () async {
      repository.foods = const [];

      await viewModel.generateRecipe();

      expect(pantry.scans, isEmpty);
      expect(viewModel.errorMessage, isNotNull);
    });

    test('falha ao guardar não impede de seguir com a receita', () async {
      pantry.error = Exception('disco cheio');

      await viewModel.generateRecipe();

      expect(viewModel.foodsDetected, isTrue);
      expect(viewModel.detectedIngredients, ['tomate', 'ovo', 'cebola']);
      expect(viewModel.errorMessage, isNull);
      expect(viewModel.isLoading, isFalse);

      await viewModel.generateRecipe();

      expect(viewModel.recipe, isNotNull);
    });
  });

  test(
    'remove ingredientes antes de gerar e envia apenas os restantes',
    () async {
      final repository = _FakeAiRepository();
      final viewModel = AiRecipesViewModel(
        repository: repository,
        pantryRepository: FakePantryRepository(),
      );
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
    final viewModel = AiRecipesViewModel(
      repository: repository,
      pantryRepository: FakePantryRepository(),
    );
    viewModel.setImage(bytes: Uint8List.fromList([1]), mimeType: 'image/jpeg');
    viewModel.setServings(5);

    await viewModel.generateRecipe();
    await viewModel.generateRecipe();

    expect(repository.generatedServings, 5);
    expect(viewModel.recipe?.servings, 5);
  });

  test('envia a localização regional selecionada', () async {
    final repository = _FakeAiRepository();
    final viewModel = AiRecipesViewModel(
      repository: repository,
      pantryRepository: FakePantryRepository(),
    );
    viewModel.setImage(bytes: Uint8List.fromList([1]), mimeType: 'image/jpeg');
    viewModel.setLocation('Curitiba, PR');

    await viewModel.generateRecipe();
    await viewModel.generateRecipe();

    expect(repository.generatedLocation, 'Curitiba, PR');
  });

  test('ignora quantidade de pessoas menor que o mínimo', () {
    final viewModel = AiRecipesViewModel(
      repository: _FakeAiRepository(),
      pantryRepository: FakePantryRepository(),
    );

    viewModel.setServings(AiRecipesViewModel.minServings - 1);
    expect(viewModel.servings, AiRecipesViewModel.defaultServings);
    viewModel.setServings(100);
    expect(viewModel.servings, 100);
  });

  test(
    'desabilita a geração quando todos os ingredientes são removidos',
    () async {
      final repository = _FakeAiRepository();
      final viewModel = AiRecipesViewModel(
        repository: repository,
        pantryRepository: FakePantryRepository(),
      );
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
