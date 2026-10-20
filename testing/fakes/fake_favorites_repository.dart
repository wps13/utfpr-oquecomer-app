import 'package:o_que_comer_app/data/repositories/favorites_repository.dart';
import 'package:o_que_comer_app/domain/models/recipe.dart';

/// Repositório falso para testes de ViewModel.
class FakeFavoritesRepository implements FavoritesRepository {
  FakeFavoritesRepository([List<Recipe> initial = const []])
    : items = [...initial];

  final List<Recipe> items;
  Exception? error;

  void _check() {
    final e = error;
    if (e != null) throw e;
  }

  @override
  Future<List<Recipe>> getFavorites() async {
    _check();
    return List.unmodifiable(items);
  }

  @override
  Future<void> save(Recipe favorite) async {
    _check();
    items.removeWhere((item) => item.id == favorite.id);
    items.add(favorite);
  }

  @override
  Future<void> add(Recipe favorite) async {
    _check();
    items.add(favorite);
  }

  @override
  Future<void> remove(String id) async {
    _check();
    items.removeWhere((f) => f.id == id);
  }

  @override
  Future<bool> isFavorite(String id) async {
    _check();
    return items.any((item) => item.id == id);
  }
}
