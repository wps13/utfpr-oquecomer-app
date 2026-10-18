import '../../domain/models/favorite.dart';

/// Fonte da verdade dos favoritos. A ViewModel depende só desta interface.
abstract interface class FavoritesRepository {
  Future<List<Favorite>> getFavorites();

  Future<void> add(Favorite favorite);

  Future<void> remove(String id);
}

/// Implementação em memória, até existir persistência local.
class InMemoryFavoritesRepository implements FavoritesRepository {
  final List<Favorite> _items = [
    const Favorite(id: '1', name: 'Lasanha'),
    const Favorite(id: '2', name: 'Risoto de cogumelos'),
  ];

  @override
  Future<List<Favorite>> getFavorites() async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    return List.unmodifiable(_items);
  }

  @override
  Future<void> add(Favorite favorite) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    _items.add(favorite);
  }

  @override
  Future<void> remove(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    _items.removeWhere((f) => f.id == id);
  }
}
