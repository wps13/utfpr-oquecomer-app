import '../../domain/models/recipe.dart';
import '../../domain/models/recipe_category.dart';

/// Repositório injetável nas ViewModels de catálogo, busca e detalhe.
abstract interface class CatalogRepository {
  Future<List<RecipeCategory>> getCategories();

  Future<List<Recipe>> getRecipesByCategory(String category);

  Future<List<Recipe>> listRecipes({int page = 1, int limit = 20});

  /// Consulta todas as páginas para filtros locais sem omitir receitas.
  Future<List<Recipe>> getAllRecipes();

  Future<List<Recipe>> searchByName(
    String name, {
    int page = 1,
    int limit = 20,
  });

  /// A API não oferece essa busca: consulta as páginas e filtra no app.
  Future<List<Recipe>> searchByIngredient(String ingredient);

  Future<Recipe> getRecipe(String id);
}
