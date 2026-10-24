import '../../domain/models/recipe.dart';

/// Repositório injetável nas ViewModels de catálogo, busca e detalhe.
abstract interface class CatalogRepository {
  Future<List<Recipe>> listRecipes({int page = 1, int limit = 20});

  Future<List<Recipe>> searchByName(
    String name, {
    int page = 1,
    int limit = 20,
  });

  /// A API não oferece essa busca: consulta as páginas e filtra no app.
  Future<List<Recipe>> searchByIngredient(String ingredient);

  Future<Recipe> getRecipe(String id);
}
