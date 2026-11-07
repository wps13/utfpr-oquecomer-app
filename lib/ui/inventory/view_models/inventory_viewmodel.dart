import 'package:flutter/foundation.dart';

import '../../../data/repositories/pantry_repository.dart';
import '../../../domain/models/pantry_item.dart';
import '../../core/view_state.dart';

class InventoryViewModel extends ChangeNotifier {
  InventoryViewModel({required PantryRepository repository})
    // ignore: prefer_initializing_formals
    : _repository = repository;

  final PantryRepository _repository;

  ViewState _state = ViewState.loading;
  List<PantryItem> _items = const [];
  String? _errorMessage;
  bool _disposed = false;

  ViewState get state => _state;
  List<PantryItem> get items => _items;
  String? get errorMessage => _errorMessage;

  Future<void> load() => _run(() async {
    _items = await _repository.getItems();
  });

  Future<void> remove(String id) async {
    final previous = _items;
    _items = previous.where((item) => item.id != id).toList();
    _notify();
    try {
      await _repository.remove(id);
      _errorMessage = null;
      _setState(ViewState.success);
    } on Object catch (error) {
      _items = previous;
      _errorMessage = error.toString();
      _notify();
      _setState(ViewState.error);
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    _setState(ViewState.loading);
    try {
      await action();
      _errorMessage = null;
      _setState(ViewState.success);
    } on Object catch (error) {
      _errorMessage = error.toString();
      _setState(ViewState.error);
    }
  }

  void _setState(ViewState state) {
    if (_disposed) return;
    _state = state;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
