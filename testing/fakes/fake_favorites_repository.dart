import 'package:o_que_comer_app/data/repositories/favorites_repository.dart';
import 'package:o_que_comer_app/domain/models/favorite.dart';

/// Repositório falso para testes de ViewModel.
class FakeFavoritesRepository implements FavoritesRepository {
  FakeFavoritesRepository([List<Favorite> initial = const []])
    : items = [...initial];

  final List<Favorite> items;
  Exception? error;

  void _check() {
    final e = error;
    if (e != null) throw e;
  }

  @override
  Future<List<Favorite>> getFavorites() async {
    _check();
    return List.unmodifiable(items);
  }

  @override
  Future<void> add(Favorite favorite) async {
    _check();
    items.add(favorite);
  }

  @override
  Future<void> remove(String id) async {
    _check();
    items.removeWhere((f) => f.id == id);
  }
}
