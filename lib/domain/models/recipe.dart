enum RecipeSource { catalog, ai }

/// Modelo compartilhado pelo catálogo, geração de IA e futuros favoritos.
/// A criação de uma receita não implica sua persistência.
class Recipe {
  Recipe({
    required this.id,
    required this.title,
    required List<String> ingredients,
    required List<String> steps,
    required this.source,
    this.description = '',
    this.preparationMinutes = 1,
    this.servings = 1,
    this.favoritedAt,
    this.imageUrl,
    this.type,
    this.createdAt,
    List<String> baseIngredients = const [],
  }) : ingredients = List.unmodifiable(ingredients),
       steps = List.unmodifiable(steps),
       baseIngredients = List.unmodifiable(baseIngredients);

  factory Recipe.fromJson(Map<String, Object?> json) {
    final isApiPayload = !json.containsKey('title');
    final source = switch (json['source'] ?? json['origem']) {
      'catalog' => RecipeSource.catalog,
      'ai' => RecipeSource.ai,
      _ => throw const FormatException('Origem de receita inválida.'),
    };
    final apiIngredients = json['ingredients'] ?? json['ingredientes'];
    final apiSteps = json['steps'] ?? json['modo_preparo'];
    return Recipe(
      id: _text(json['id']),
      title: _text(json['title'] ?? json['receita']),
      description: !isApiPayload && json['description'] == null
          ? _text(json['description'])
          : _optionalText(json['description']),
      ingredients: isApiPayload && apiIngredients is String
          ? [apiIngredients]
          : _texts(apiIngredients),
      steps: isApiPayload && apiSteps is String ? [apiSteps] : _texts(apiSteps),
      preparationMinutes: _positiveInt(
        isApiPayload
            ? (json['preparationMinutes'] ?? 1)
            : json['preparationMinutes'],
      ),
      servings: _positiveInt(
        isApiPayload ? (json['servings'] ?? 1) : json['servings'],
      ),
      source: source,
      favoritedAt: _date(json['favoritada_em']),
      imageUrl: json['link_imagem'] as String?,
      type: json['tipo'] as String?,
      createdAt: _date(json['created_at']),
      baseIngredients: (json['IngredientesBase'] as List? ?? const [])
          .whereType<String>()
          .toList(growable: false),
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
  final DateTime? favoritedAt;
  final String? imageUrl;
  final String? type;
  final DateTime? createdAt;
  final List<String> baseIngredients;

  String get name => title;

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'ingredients': ingredients,
    'steps': steps,
    'preparationMinutes': preparationMinutes,
    'servings': servings,
    'source': source.name,
    'receita': title,
    'ingredientes': ingredients.join(', '),
    'modo_preparo': steps.join('\n'),
    'origem': source.name,
    'favoritada_em': favoritedAt?.toIso8601String(),
    'link_imagem': imageUrl,
    'tipo': type,
    'created_at': createdAt?.toIso8601String(),
    'IngredientesBase': baseIngredients,
  };

  @override
  bool operator ==(Object other) =>
      other is Recipe &&
      other.id == id &&
      other.title == title &&
      other.description == description &&
      _listEquals(other.ingredients, ingredients) &&
      _listEquals(other.steps, steps) &&
      other.preparationMinutes == preparationMinutes &&
      other.servings == servings &&
      other.source == source &&
      other.favoritedAt == favoritedAt &&
      other.imageUrl == imageUrl &&
      other.type == type &&
      other.createdAt == createdAt &&
      _listEquals(other.baseIngredients, baseIngredients);

  @override
  int get hashCode => Object.hash(
    id,
    title,
    description,
    Object.hashAll(ingredients),
    Object.hashAll(steps),
    preparationMinutes,
    servings,
    source,
    favoritedAt,
    imageUrl,
    type,
    createdAt,
    Object.hashAll(baseIngredients),
  );

  Recipe copyWithFavoritedAt(DateTime date) => Recipe(
    id: id,
    title: title,
    description: description,
    ingredients: ingredients,
    steps: steps,
    preparationMinutes: preparationMinutes,
    servings: servings,
    source: source,
    favoritedAt: date,
    imageUrl: imageUrl,
    type: type,
    createdAt: createdAt,
    baseIngredients: baseIngredients,
  );

  static String _text(Object? value) {
    if (value is! String || value.trim().isEmpty) {
      throw const FormatException('Texto de receita inválido.');
    }
    return value.trim();
  }

  static String _optionalText(Object? value) =>
      value is String ? value.trim() : '';

  static DateTime? _date(Object? value) =>
      value is String ? DateTime.tryParse(value)?.toUtc() : null;

  static bool _listEquals(List<String> first, List<String> second) {
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index++) {
      if (first[index] != second[index]) return false;
    }
    return true;
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
