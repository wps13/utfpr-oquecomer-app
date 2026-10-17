abstract final class Routes {
  static const home = '/';
  static const search = '/busca';
  static const favorites = '/favoritos';
  static const catalog = '/catalogo';
  static const inventory = '/despensa';
  static const aiRecipe = '/ia';
  static String recipeDetails(String id) => '/receitas/$id';
  static String handsFreeMode(String id) => '/receitas/$id/hands-free';
}
