import 'package:flutter/foundation.dart';

import '../../../data/repositories/catalog_repository.dart';
import '../../../domain/errors/app_failure.dart';
import '../../../domain/models/recipe.dart';
import '../../../domain/models/recipe_category.dart';
import '../../core/view_state.dart';

class CatalogViewModel extends ChangeNotifier {
  CatalogViewModel({required CatalogRepository repository, this.category})
    // ignore: prefer_initializing_formals
    : _repository = repository;

  final CatalogRepository _repository;
  final RecipeCategory? category;
  ViewState _state = ViewState.loading;
  List<Recipe> _recipes = const [];
  String? _errorMessage;
  int _request = 0;
  bool _disposed = false;

  ViewState get state => _state;
  List<Recipe> get recipes => _recipes;
  String? get errorMessage => _errorMessage;
  String get title => category?.label ?? 'Catálogo';

  Future<void> load() async {
    if (_disposed) return;
    final request = ++_request;
    _errorMessage = null;
    if (_state != ViewState.loading) {
      _state = ViewState.loading;
      notifyListeners();
    }
    try {
      final recipes = category == null
          ? await _repository.listRecipes(limit: 100)
          : await _repository.getRecipesByCategory(category!.id);
      if (_disposed || request != _request) return;
      _recipes = List.unmodifiable(recipes);
      _state = ViewState.success;
    } on Object catch (error) {
      if (_disposed || request != _request) return;
      _recipes = const [];
      _errorMessage = error is AppFailure
          ? error.message
          : 'Tente novamente em instantes.';
      _state = ViewState.error;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
