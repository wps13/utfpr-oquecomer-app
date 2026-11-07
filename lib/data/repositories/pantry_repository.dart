import 'package:hive_ce/hive.dart';

import '../../domain/models/pantry_item.dart';
import '../services/errors/error_reporter.dart';

abstract interface class PantryBox {
  Iterable<Object?> get values;

  Object? get(String key);

  Future<void> delete(String key);

  /// Grava todas as entradas de uma vez.
  Future<void> putAll(Map<String, Map<String, Object?>> entries);
}

/// Fonte da verdade da despensa. A ViewModel depende só desta interface.
abstract interface class PantryRepository {
  /// Guarda os alimentos detectados em um escaneamento, todos com a mesma
  /// data. Um alimento que já está na despensa não é duplicado: o item
  /// existente mantém o nome e recebe a data do novo escaneamento.
  Future<void> saveScanned(List<String> foods);

  /// Itens da despensa, do escaneamento mais recente para o mais antigo.
  Future<List<PantryItem>> getItems();

  Future<void> remove(String id);
}

/// Implementação usada pela aplicação, sobre uma [PantryBox] (Hive ou memória).
class LocalPantryRepository implements PantryRepository {
  LocalPantryRepository({
    required this.box,
    required this.errorReporter,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final PantryBox box;
  final ErrorReporter errorReporter;
  final DateTime Function() _now;

  @override
  Future<void> saveScanned(List<String> foods) => _guard('write', () async {
    final scannedAt = _now().toUtc();
    final entries = <String, Map<String, Object?>>{};
    for (final food in foods) {
      final id = PantryItem.idFor(food);
      if (id.isEmpty || entries.containsKey(id)) continue;
      final item =
          _existing(id) ?? PantryItem(name: food, scannedAt: scannedAt);
      entries[id] = item.copyWithScannedAt(scannedAt).toJson();
    }
    if (entries.isEmpty) return;
    await box.putAll(entries);
  });

  @override
  Future<List<PantryItem>> getItems() => _guard('read', () async {
    final items = box.values.map((value) {
      if (value is! Map) {
        throw const FormatException('Registro de despensa inválido.');
      }
      return PantryItem.fromJson(Map<String, Object?>.from(value));
    }).toList();
    items.sort((a, b) {
      final byDate = b.scannedAt.compareTo(a.scannedAt);
      return byDate != 0 ? byDate : a.id.compareTo(b.id);
    });
    return List.unmodifiable(items);
  });

  @override
  Future<void> remove(String id) =>
      _guard<void>('delete', () => box.delete(id));

  /// Registro ilegível é tratado como inexistente e sobrescrito.
  PantryItem? _existing(String id) {
    final value = box.get(id);
    if (value is! Map) return null;
    try {
      return PantryItem.fromJson(Map<String, Object?>.from(value));
    } on FormatException {
      return null;
    }
  }

  Future<T> _guard<T>(String operation, Future<T> Function() action) async {
    try {
      return await action();
    } on Object catch (error, stack) {
      await errorReporter.recordError(
        PantryStorageError(operation),
        stack,
        reason: 'Falha no armazenamento local da despensa',
      );
      rethrow;
    }
  }
}

class HivePantryBox implements PantryBox {
  HivePantryBox(this._box);

  final Box<dynamic> _box;

  @override
  Iterable<Object?> get values => _box.values;

  @override
  Object? get(String key) => _box.get(key);

  @override
  Future<void> delete(String key) => _box.delete(key);

  @override
  Future<void> putAll(Map<String, Map<String, Object?>> entries) =>
      _box.putAll(entries);
}

/// Sem persistência: usada quando o armazenamento local não abre.
class InMemoryPantryBox implements PantryBox {
  final Map<String, Map<String, Object?>> _entries = {};

  @override
  Iterable<Object?> get values => _entries.values;

  @override
  Object? get(String key) => _entries[key];

  @override
  Future<void> delete(String key) async {
    _entries.remove(key);
  }

  @override
  Future<void> putAll(Map<String, Map<String, Object?>> entries) async =>
      _entries.addAll(entries);
}

class PantryStorageError implements Exception {
  const PantryStorageError(this.operation);

  final String operation;

  @override
  String toString() => 'PantryStorageError($operation)';
}
