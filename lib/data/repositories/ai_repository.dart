import 'dart:typed_data';

import '../../domain/models/recipe.dart';

/// Injete na ViewModel da funcionalidade que utiliza IA.
abstract interface class AiRepository {
  Future<Recipe> generateRecipe(List<String> ingredients, {int servings = 2});

  /// JPEG, PNG ou WebP, até 10 MiB. Uma lista vazia significa nenhum alimento.
  Future<List<String>> identifyFoods({
    required Uint8List imageBytes,
    required String mimeType,
  });
}
