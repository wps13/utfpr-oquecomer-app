import '../../domain/models/recipe.dart';

/// Contrato externo da API-Receitas, separado da serialização dos favoritos.
class CatalogRecipeDto {
  CatalogRecipeDto._({
    required this.id,
    required this.title,
    required this.ingredients,
    required this.preparation,
    required this.imageUrl,
    required this.type,
    required this.createdAt,
    required List<String> baseIngredients,
  }) : baseIngredients = List.unmodifiable(baseIngredients);

  factory CatalogRecipeDto.fromJson(Object? json) {
    final data = _object(json);
    final id = _integer(data['id'], minimum: 1);
    final rawBaseIngredients = data['IngredientesBase'];
    final baseIngredients = <String>[];
    if (rawBaseIngredients != null) {
      if (rawBaseIngredients is! List) {
        throw const FormatException('Ingredientes base inválidos.');
      }
      for (final group in rawBaseIngredients) {
        final names = _object(group)['nomesIngrediente'];
        if (names is! List) {
          throw const FormatException('Nomes de ingredientes inválidos.');
        }
        baseIngredients.addAll(names.map(_text));
      }
    }
    final rawDate = _optionalText(data['created_at']);
    final date = rawDate == null ? null : DateTime.tryParse(rawDate);
    if (rawDate != null && date == null) {
      throw const FormatException('Data de receita inválida.');
    }
    return CatalogRecipeDto._(
      id: id,
      title: _text(data['receita']),
      ingredients: _text(data['ingredientes']),
      preparation: _text(data['modo_preparo']),
      imageUrl: _optionalText(data['link_imagem']),
      type: _optionalText(data['tipo']),
      createdAt: date?.toUtc(),
      baseIngredients: baseIngredients,
    );
  }

  final int id;
  final String title;
  final String ingredients;
  final String preparation;
  final String? imageUrl;
  final String? type;
  final DateTime? createdAt;
  final List<String> baseIngredients;

  Recipe toRecipe() => Recipe(
    id: id.toString(),
    title: title,
    // Os textos não têm delimitadores confiáveis: preservar quantidades,
    // vírgulas decimais e a numeração do modo de preparo evita perda de dados.
    ingredients: [ingredients],
    steps: [preparation],
    source: RecipeSource.catalog,
    preparationMinutes: null,
    imageUrl: imageUrl,
    type: type,
    createdAt: createdAt,
    baseIngredients: baseIngredients,
  );
}

/// A API publicada usa `items` e os metadados do nestjs-typeorm-paginate.
class CatalogPageDto {
  CatalogPageDto._({
    required List<CatalogRecipeDto> items,
    required this.currentPage,
    required this.totalPages,
    required this.itemsPerPage,
  }) : items = List.unmodifiable(items);

  factory CatalogPageDto.fromJson(Object? json) {
    final data = _object(json);
    final rawItems = data['items'];
    if (rawItems is! List) {
      throw const FormatException('Lista de receitas inválida.');
    }
    final meta = _object(data['meta']);
    final currentPage = _integer(meta['currentPage'], minimum: 1);
    final totalPages = _integer(meta['totalPages']);
    final itemsPerPage = _integer(meta['itemsPerPage'], minimum: 1);
    final itemCount = _integer(meta['itemCount']);
    final totalItems = _integer(meta['totalItems']);
    if (itemCount != rawItems.length ||
        itemCount > itemsPerPage ||
        totalItems < itemCount ||
        totalPages != (totalItems / itemsPerPage).ceil() ||
        (currentPage < totalPages && itemCount != itemsPerPage)) {
      throw const FormatException('Paginação de receitas inconsistente.');
    }
    return CatalogPageDto._(
      items: rawItems.map(CatalogRecipeDto.fromJson).toList(growable: false),
      currentPage: currentPage,
      totalPages: totalPages,
      itemsPerPage: itemsPerPage,
    );
  }

  final List<CatalogRecipeDto> items;
  final int currentPage;
  final int totalPages;
  final int itemsPerPage;

  bool get hasNextPage => currentPage < totalPages;
}

Map<String, Object?> _object(Object? value) {
  if (value is! Map<String, Object?>) {
    throw const FormatException('Objeto de receita inválido.');
  }
  return value;
}

String _text(Object? value) {
  if (value is! String || value.trim().isEmpty) {
    throw const FormatException('Texto de receita inválido.');
  }
  return value.trim();
}

String? _optionalText(Object? value) {
  if (value == null) return null;
  if (value is! String) {
    throw const FormatException('Texto opcional de receita inválido.');
  }
  final text = value.trim();
  return text.isEmpty ? null : text;
}

int _integer(Object? value, {int minimum = 0}) {
  if (value is! int || value < minimum) {
    throw const FormatException('Número de receita inválido.');
  }
  return value;
}
