import 'package:flutter/foundation.dart';

import '../../../data/repositories/favorites_repository.dart';
import '../../../domain/models/recipe.dart';
import '../../core/view_state.dart';

/// ViewModel modelo: repositório injetado no construtor, estado explícito
/// (loading/success/error) e `notifyListeners()` a cada mudança de estado.
class FavoritesViewModel extends ChangeNotifier {
  FavoritesViewModel({required FavoritesRepository repository})
    // ignore: prefer_initializing_formals
    : _repository = repository;

  final FavoritesRepository _repository;

  ViewState _state = ViewState.loading;
  List<Recipe> _favorites = const [];
  String? _errorMessage;
  bool _disposed = false;

  ViewState get state => _state;
  List<Recipe> get favorites => _favorites;
  String? get errorMessage => _errorMessage;

  /// Carrega os favoritos. Chamar do `initState` ou de um callback.
  Future<void> load() => _run(() async {
    _favorites = await _repository.getFavorites();
  });

  Future<void> add(String name) => _run(() async {
    final favorite = Recipe(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: name,
      ingredients: const ['Não informado'],
      steps: const ['Não informado'],
      source: RecipeSource.catalog,
    );
    await _repository.add(favorite);
    _favorites = await _repository.getFavorites();
  });

  Future<void> saveRecipe(Recipe recipe) => _run(() async {
    await _repository.save(recipe.copyWithFavoritedAt(DateTime.now().toUtc()));
    _favorites = await _repository.getFavorites();
  });

  Future<void> remove(String id) => _run(() async {
    await _repository.remove(id);
    _favorites = await _repository.getFavorites();
  });

  Future<void> _run(Future<void> Function() action) async {
    // O estado inicial já é `loading`; assim a chamada feita no initState
    // não notifica durante o build.
    _setState(ViewState.loading);
    try {
      await action();
      _errorMessage = null;
      _setState(ViewState.success);
    } on Object catch (e) {
      _errorMessage = e.toString();
      _setState(ViewState.error);
    }
  }

  void _setState(ViewState state) {
    if (_disposed) return;
    if (_state == state) return;
    _state = state;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
