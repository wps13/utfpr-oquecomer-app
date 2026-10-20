enum RecipeSource { catalog, ai }

/// Modelo compartilhado pelo catálogo, geração de IA e futuros favoritos.
/// A criação de uma receita não implica sua persistência.
class Recipe {
  Recipe({
    required this.id,
    required this.title,
    required this.description,
    required List<String> ingredients,
    required List<String> steps,
    required this.preparationMinutes,
    required this.servings,
    required this.source,
  }) : ingredients = List.unmodifiable(ingredients),
       steps = List.unmodifiable(steps);

  factory Recipe.fromJson(Map<String, Object?> json) {
    final source = switch (json['source']) {
      'catalog' => RecipeSource.catalog,
      'ai' => RecipeSource.ai,
      _ => throw const FormatException('Origem de receita inválida.'),
    };
    return Recipe(
      id: _text(json['id']),
      title: _text(json['title']),
      description: _text(json['description']),
      ingredients: _texts(json['ingredients']),
      steps: _texts(json['steps']),
      preparationMinutes: _positiveInt(json['preparationMinutes']),
      servings: _positiveInt(json['servings']),
      source: source,
    );
  }

  final String id;
  final String title;
  final String description;
  final List<String> ingredients;
  final List<String> steps;
  final int preparationMinutes;
  final int servings;
  final RecipeSource source;

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'ingredients': ingredients,
    'steps': steps,
    'preparationMinutes': preparationMinutes,
    'servings': servings,
    'source': source.name,
  };

  static String _text(Object? value) {
    if (value is! String || value.trim().isEmpty) {
      throw const FormatException('Texto de receita inválido.');
    }
    return value.trim();
  }

  static List<String> _texts(Object? value) {
    if (value is! List || value.isEmpty) {
      throw const FormatException('Lista de receita inválida.');
    }
    return value.map(_text).toList(growable: false);
  }

  static int _positiveInt(Object? value) {
    if (value is! num || !value.isFinite || value <= 0 || value % 1 != 0) {
      throw const FormatException('Número de receita inválido.');
    }
    return value.toInt();
  }
}
