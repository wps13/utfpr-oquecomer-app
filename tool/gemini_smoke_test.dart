// Execução manual: flutter test tool/gemini_smoke_test.dart
//   --dart-define-from-file=config/gemini.local.json
// Uma foto opcional pode ser definida em GEMINI_SMOKE_IMAGE.
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:o_que_comer_app/config/ai_dependencies.dart';
import 'package:o_que_comer_app/config/gemini_config.dart';
import 'package:o_que_comer_app/data/services/errors/error_reporter.dart';
import 'package:o_que_comer_app/domain/models/recipe.dart';

void main() {
  const config = GeminiConfig.fromEnvironment();
  const photoPath = String.fromEnvironment('GEMINI_SMOKE_IMAGE');
  late AiDependencies dependencies;

  setUp(() {
    expect(
      config.isValid,
      isTrue,
      reason: 'Configure GEMINI_API_KEY no arquivo local ignorado pelo Git.',
    );
    dependencies = AiDependencies(errorReporter: const DisabledErrorReporter());
    addTearDown(dependencies.close);
  });

  test('API real gera uma receita em português', () async {
    final recipe = await dependencies.repository.generateRecipe([
      'ovos',
      'tomate',
      'cebola',
    ]);
    expect(recipe.source, RecipeSource.ai);
    expect(recipe.title, isNotEmpty);
    expect(recipe.ingredients, isNotEmpty);
    expect(recipe.steps, isNotEmpty);
    expect(recipe.servings, greaterThan(0));
    expect(recipe.preparationMinutes, greaterThan(0));
  });

  test(
    'API real identifica alimentos em uma foto local',
    () async {
      final extension = photoPath.split('.').last.toLowerCase();
      final mimeType = switch (extension) {
        'jpg' || 'jpeg' => 'image/jpeg',
        'png' => 'image/png',
        'webp' => 'image/webp',
        _ => throw ArgumentError('Use uma foto JPEG, PNG ou WebP.'),
      };
      final foods = await dependencies.repository.identifyFoods(
        imageBytes: await File(photoPath).readAsBytes(),
        mimeType: mimeType,
      );
      debugPrint(
        foods.isEmpty
            ? 'Nenhum alimento reconhecido na foto.'
            : 'Alimentos identificados: ${foods.join(', ')}',
      );
      // O retorno vazio é válido quando não há alimentos reconhecíveis.
      expect(foods.every((food) => food.trim().isNotEmpty), isTrue);
    },
    skip: photoPath.isEmpty
        ? 'Defina GEMINI_SMOKE_IMAGE para testar foto.'
        : false,
  );
}
