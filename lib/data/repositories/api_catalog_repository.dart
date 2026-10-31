import '../../domain/errors/app_failure.dart';
import '../../domain/models/recipe.dart';
import '../model/catalog_recipe_dto.dart';
import '../services/api/api_client.dart';
import '../services/errors/error_reporter.dart';
import 'catalog_repository.dart';

class ApiCatalogRepository implements CatalogRepository {
  const ApiCatalogRepository({
    required this.client,
    required this.errorReporter,
  });

  final CatalogApiClient client;
  final ErrorReporter errorReporter;

  @override
  Future<List<Recipe>> listRecipes({int page = 1, int limit = 20}) =>
      _guard('listRecipes', () async {
        final result = await _fetchPage(
          '/receitas/todas',
          page: page,
          limit: limit,
        );
        return _recipes(result.items);
      });

  @override
  Future<List<Recipe>> searchByName(
    String name, {
    int page = 1,
    int limit = 20,
  }) => _guard('searchByName', () async {
    _validatePagination(page, limit);
    final query = name.trim();
    if (query.isEmpty) return const [];
    final result = await _fetchPage(
      '/receitas/descricao',
      page: page,
      limit: limit,
      queryParameters: {'descricao': query},
    );
    return _recipes(result.items);
  });

  @override
  Future<List<Recipe>> searchByIngredient(String ingredient) =>
      _guard('searchByIngredient', () async {
        final query = _normalize(ingredient.trim());
        if (query.isEmpty) return const [];
        final matches = <String, Recipe>{};
        var page = 1;
        while (true) {
          final result = await _fetchPage(
            '/receitas/todas',
            page: page,
            limit: 100,
          );
          for (final item in result.items) {
            // Não pesquisar no título: o termo deve estar nos ingredientes.
            final candidates = [item.ingredients, ...item.baseIngredients];
            if (candidates.any((text) => _normalize(text).contains(query))) {
              final recipe = item.toRecipe();
              matches[recipe.id] = recipe;
            }
          }
          if (!result.hasNextPage) return List.unmodifiable(matches.values);
          page++;
        }
      });

  @override
  Future<Recipe> getRecipe(String id) => _guard('getRecipe', () async {
    if (!RegExp(r'^[1-9][0-9]*$').hasMatch(id)) {
      throw const InvalidInputFailure('Identificador de receita inválido');
    }
    final data = await client.get<Object?>('/receitas/$id');
    final result = CatalogRecipeDto.fromJson(data);
    if (result.id.toString() != id) {
      throw const FormatException('Identificador de resposta incompatível.');
    }
    return result.toRecipe();
  });

  Future<CatalogPageDto> _fetchPage(
    String path, {
    required int page,
    required int limit,
    Map<String, Object?> queryParameters = const {},
  }) async {
    _validatePagination(page, limit);
    final data = await client.get<Object?>(
      path,
      queryParameters: {...queryParameters, 'page': page, 'limit': limit},
    );
    final result = CatalogPageDto.fromJson(data);
    if (result.currentPage != page || result.itemsPerPage != limit) {
      throw const FormatException('Página de resposta incompatível.');
    }
    return result;
  }

  Future<T> _guard<T>(String operation, Future<T> Function() action) async {
    try {
      return await action();
    } on InvalidResponseFailure catch (failure, stack) {
      await _report(operation, failure.runtimeType.toString(), stack);
      rethrow;
    } on AppFailure {
      // Falhas de transporte inesperadas já são reportadas pelo cliente HTTP.
      rethrow;
    } on FormatException catch (error, stack) {
      await _report(operation, error.runtimeType.toString(), stack);
      throw const InvalidResponseFailure();
    } on Object catch (error, stack) {
      final safeError = CatalogIntegrationError(
        operation,
        error.runtimeType.toString(),
      );
      await _report(operation, error.runtimeType.toString(), stack);
      throw UnexpectedFailure(safeError, stack);
    }
  }

  Future<void> _report(String operation, String type, StackTrace stack) async {
    try {
      await errorReporter.recordError(
        CatalogIntegrationError(operation, type),
        stack,
        reason: 'Falha na integração do catálogo de receitas',
      );
    } on Object {
      // A falha de telemetria não substitui o erro devolvido à ViewModel.
    }
  }

  static List<Recipe> _recipes(List<CatalogRecipeDto> items) =>
      List.unmodifiable(items.map((item) => item.toRecipe()));

  static void _validatePagination(int page, int limit) {
    if (page < 1 || limit < 1 || limit > 100) {
      throw const InvalidInputFailure(
        'Informe página positiva e limite entre 1 e 100',
      );
    }
  }

  static String _normalize(String text) {
    const accents = 'áàâãäéèêëíìîïóòôõöúùûüç';
    const plain = 'aaaaaeeeeiiiiooooouuuuc';
    return text.toLowerCase().split('').map((character) {
      final index = accents.indexOf(character);
      return index < 0 ? character : plain[index];
    }).join();
  }
}

/// Contexto de diagnóstico sem resposta completa nem termo pesquisado.
class CatalogIntegrationError implements Exception {
  const CatalogIntegrationError(this.operation, this.errorType);

  final String operation;
  final String errorType;

  @override
  String toString() => 'CatalogIntegrationError($operation, $errorType)';
}
