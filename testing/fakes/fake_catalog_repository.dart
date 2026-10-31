import 'package:o_que_comer_app/data/repositories/catalog_repository.dart';
import 'package:o_que_comer_app/domain/models/recipe.dart';
import 'package:o_que_comer_app/domain/models/recipe_category.dart';

class FakeCatalogRepository implements CatalogRepository {
  List<RecipeCategory> categories = const [];
  List<Recipe> recipes = const [];
  Future<List<RecipeCategory>> Function()? loadCategories;
  Future<List<Recipe>> Function(String)? loadRecipes;
  Future<List<Recipe>> Function()? loadAllRecipes;
  int categoryCalls = 0;
  int listCalls = 0;
  int allRecipesCalls = 0;
  final requestedCategories = <String>[];

  @override
  Future<List<RecipeCategory>> getCategories() async {
    categoryCalls++;
    return loadCategories == null ? categories : await loadCategories!();
  }

  @override
  Future<List<Recipe>> getRecipesByCategory(String category) async {
    requestedCategories.add(category);
    return loadRecipes == null
        ? recipes.where((item) => item.type == category).toList()
        : await loadRecipes!(category);
  }

  @override
  Future<List<Recipe>> listRecipes({int page = 1, int limit = 20}) async {
    listCalls++;
    return recipes;
  }

  @override
  Future<List<Recipe>> getAllRecipes() async {
    allRecipesCalls++;
    return loadAllRecipes == null ? recipes : await loadAllRecipes!();
  }

  @override
  Future<Recipe> getRecipe(String id) => throw UnimplementedError();

  @override
  Future<List<Recipe>> searchByIngredient(String ingredient) =>
      throw UnimplementedError();

  @override
  Future<List<Recipe>> searchByName(
    String name, {
    int page = 1,
    int limit = 20,
  }) => throw UnimplementedError();
}
