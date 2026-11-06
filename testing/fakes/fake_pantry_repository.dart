import 'package:o_que_comer_app/data/repositories/pantry_repository.dart';
import 'package:o_que_comer_app/domain/models/pantry_item.dart';

/// Repositório falso para testes de ViewModel: registra o que foi salvo.
class FakePantryRepository implements PantryRepository {
  final scans = <List<String>>[];
  final items = <PantryItem>[];
  final removedIds = <String>[];
  Exception? error;

  @override
  Future<void> saveScanned(List<String> foods) async {
    final e = error;
    if (e != null) throw e;
    scans.add(List.of(foods));
  }

  @override
  Future<List<PantryItem>> getItems() async {
    final e = error;
    if (e != null) throw e;
    return List.unmodifiable(items);
  }

  @override
  Future<void> remove(String id) async {
    final e = error;
    if (e != null) throw e;
    removedIds.add(id);
    items.removeWhere((item) => item.id == id);
  }
}
