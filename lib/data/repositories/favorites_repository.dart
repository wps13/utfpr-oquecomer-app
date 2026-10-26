import 'package:hive_ce/hive.dart';

import '../../domain/models/recipe.dart';
import '../services/errors/error_reporter.dart';

abstract interface class FavoritesBox {
  Iterable<Object?> get values;

  Future<void> put(String key, Map<String, Object?> value);

  Future<void> delete(String key);

  bool containsKey(String key);
}

/// Fonte da verdade dos favoritos. A ViewModel depende só desta interface.
abstract interface class FavoritesRepository {
  Future<List<Recipe>> getFavorites();

  Future<void> save(Recipe recipe);

  Future<void> add(Recipe recipe);

  Future<void> remove(String id);

  Future<bool> isFavorite(String id);
}

/// Implementação Hive usada pela aplicação.
class HiveFavoritesRepository implements FavoritesRepository {
  HiveFavoritesRepository({required this.box, required this.errorReporter});

  final FavoritesBox box;
  final ErrorReporter errorReporter;

  @override
  Future<List<Recipe>> getFavorites() => _guard('read', () async {
    final values = box.values.map((value) {
      if (value is! Map) {
        throw const FormatException('Registro de favorito inválido.');
      }

      return Recipe.fromJson(Map<String, Object?>.from(value));
    }).toList();
    values.sort(
      (a, b) => (b.favoritedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
          .compareTo(a.favoritedAt ?? DateTime.fromMillisecondsSinceEpoch(0)),
    );
    return List.unmodifiable(values);
  });

  @override
  Future<void> save(Recipe recipe) => _guard('write', () async {
    await box.put(
      recipe.id,
      recipe
          .copyWithFavoritedAt(recipe.favoritedAt ?? DateTime.now().toUtc())
          .toJson(),
    );
  });

  @override
  Future<void> add(Recipe recipe) => save(recipe);

  Future<void> saveRecipe(Recipe recipe) =>
      add(recipe.copyWithFavoritedAt(DateTime.now().toUtc()));

  @override
  Future<void> remove(String id) =>
      _guard<void>('delete', () => box.delete(id));

  @override
  Future<bool> isFavorite(String id) => _guard('check', () async {
    return box.containsKey(id);
  });

  Future<T> _guard<T>(String operation, Future<T> Function() action) async {
    try {
      return await action();
    } on Object catch (error, stack) {
      await errorReporter.recordError(
        FavoritesStorageError(operation),
        stack,
        reason: 'Falha no armazenamento local de favoritos',
      );
      rethrow;
    }
  }
}

class HiveFavoritesBoxAdapter implements FavoritesBox {
  HiveFavoritesBoxAdapter(this._box);

  final Box<dynamic> _box;

  @override
  Iterable<Object?> get values => _box.values;

  @override
  Future<void> put(String key, Map<String, Object?> value) =>
      _box.put(key, value);

  @override
  Future<void> delete(String key) => _box.delete(key);

  @override
  bool containsKey(String key) => _box.containsKey(key);
}

class FavoritesStorageError implements Exception {
  const FavoritesStorageError(this.operation);

  final String operation;

  @override
  String toString() => 'FavoritesStorageError($operation)';
}

/// Implementação em memória para testes e protótipos sem persistência.
class InMemoryFavoritesRepository implements FavoritesRepository {
  /// Sem [initial], começa com receitas de exemplo.
  InMemoryFavoritesRepository({List<Recipe>? initial})
    : _items = initial != null ? [...initial] : _sample();

  final List<Recipe> _items;

  static List<Recipe> _sample() => [
    Recipe(
      id: '1',
      title: 'Lasanha',
      ingredients: const [''],
      steps: const [],
      source: RecipeSource.catalog,
    ),
    Recipe(
      id: '2',
      title: 'Risoto de cogumelos',
      ingredients: const [''],
      steps: const [],
      source: RecipeSource.catalog,
    ),
  ];

  @override
  Future<List<Recipe>> getFavorites() async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    return List.unmodifiable(_items);
  }

  @override
  Future<void> save(Recipe recipe) async {
    await add(recipe);
  }

  @override
  Future<void> add(Recipe recipe) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    _items.add(recipe);
  }

  @override
  Future<void> remove(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    _items.removeWhere((f) => f.id == id);
  }

  @override
  Future<bool> isFavorite(String id) async =>
      _items.any((favorite) => favorite.id == id);
}
