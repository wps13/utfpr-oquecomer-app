import 'dart:math';
import 'dart:typed_data';

import '../../domain/models/ai_failure.dart';
import '../../domain/models/recipe.dart';
import '../services/ai/gemini_prompts.dart';
import '../services/ai/gemini_schemas.dart';
import '../services/ai/gemini_service.dart';
import '../services/errors/error_reporter.dart';
import 'ai_repository.dart';

class GeminiAiRepository implements AiRepository {
  GeminiAiRepository({
    required this.service,
    required this.errorReporter,
    String Function()? createRecipeId,
  }) : _createRecipeId = createRecipeId ?? _randomRecipeId;

  final GeminiService service;
  final ErrorReporter errorReporter;
  final String Function() _createRecipeId;

  @override
  Future<Recipe> generateRecipe(List<String> ingredients, {int servings = 2}) =>
      _guard('generateRecipe', () async {
        if (ingredients.isEmpty ||
            ingredients.length > 50 ||
            ingredients.any(
              (item) => item.trim().isEmpty || item.length > 200,
            ) ||
            servings < 1) {
          throw const AiFailure(AiFailureKind.invalidInput);
        }
        final normalized = _unique(ingredients);
        final json = await service.generateJson(
          prompt: GeminiPrompts.recipe(normalized, servings),
          schema: GeminiSchemas.recipe,
        );
        if (json['servings'] != servings) {
          throw const AiFailure(AiFailureKind.invalidResponse);
        }
        return Recipe.fromJson({
          ...json,
          // Identidade criada no app: o modelo não controla IDs dos favoritos.
          'id': _createRecipeId(),
          'source': RecipeSource.ai.name,
        });
      });

  @override
  Future<List<String>> identifyFoods({
    required Uint8List imageBytes,
    required String mimeType,
  }) => _guard('identifyFoods', () async {
    if (imageBytes.isEmpty ||
        imageBytes.length > 10 * 1024 * 1024 ||
        !const {'image/jpeg', 'image/png', 'image/webp'}.contains(mimeType)) {
      throw const AiFailure(AiFailureKind.invalidInput);
    }
    final json = await service.generateJson(
      prompt: GeminiPrompts.foods,
      schema: GeminiSchemas.foods,
      imageBytes: imageBytes,
      mimeType: mimeType,
    );
    final foods = json['foods'];
    if (foods is! List ||
        foods.length > 50 ||
        foods.any(
          (item) => item is! String || item.trim().isEmpty || item.length > 200,
        )) {
      throw const AiFailure(AiFailureKind.invalidResponse);
    }
    return List.unmodifiable(_unique(foods.cast<String>()));
  });

  Future<T> _guard<T>(String operation, Future<T> Function() action) async {
    try {
      return await action();
    } on AiFailure catch (failure, stack) {
      if (failure.kind == AiFailureKind.unexpected) {
        await _report(operation, 'UnexpectedHttpStatus', stack);
      }
      rethrow;
    } on FormatException {
      throw const AiFailure(AiFailureKind.invalidResponse);
    } on Object catch (error, stack) {
      await _report(operation, error.runtimeType.toString(), stack);
      throw const AiFailure(AiFailureKind.unexpected);
    }
  }

  Future<void> _report(
    String operation,
    String errorType,
    StackTrace stack,
  ) async {
    try {
      // Não transmite mensagem original, resposta, ingredientes, foto ou chave.
      await errorReporter.recordError(
        AiIntegrationError(operation: operation, errorType: errorType),
        stack,
        reason: 'Falha inesperada na integração Gemini',
      );
    } on Object {
      // A indisponibilidade da telemetria não interrompe o retorno à ViewModel.
    }
  }

  static List<String> _unique(Iterable<String> values) {
    final seen = <String>{};
    return [
      for (final value in values)
        if (seen.add(value.trim().toLowerCase())) value.trim(),
    ];
  }

  static String _randomRecipeId() {
    final random = Random.secure();
    final bytes = List.generate(16, (_) => random.nextInt(256));
    return 'ai_${bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
  }
}

/// Contexto seguro para o Crashlytics. Nunca inclui a mensagem da exceção.
class AiIntegrationError implements Exception {
  const AiIntegrationError({required this.operation, required this.errorType});

  final String operation;
  final String errorType;

  @override
  String toString() => 'AiIntegrationError($operation, $errorType)';
}
