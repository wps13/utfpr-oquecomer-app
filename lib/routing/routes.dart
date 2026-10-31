abstract final class Routes {
  static const home = '/';
  static const search = '/busca';
  static const favorites = '/favoritos';
  static const catalog = '/catalogo';
  static String catalogByCategory(String category) =>
      Uri(path: catalog, queryParameters: {'categoria': category}).toString();
  static const inventory = '/despensa';
  static const aiRecipe = '/ia';
  static const recipes = '/receitas';
  static String recipeDetails(String id) => '/receitas/$id';
  static String handsFreeMode(String id) => '/receitas/$id/hands-free';
}
