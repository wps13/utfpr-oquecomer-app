import 'package:flutter/foundation.dart';

import '../../../data/repositories/catalog_repository.dart';
import '../../../domain/errors/app_failure.dart';
import '../../../domain/models/recipe.dart';
import '../../../utils/recipe_name_search.dart';
import '../../core/view_state.dart';

class SearchViewModel extends ChangeNotifier {
  SearchViewModel({required CatalogRepository repository})
    // ignore: prefer_initializing_formals
    : _repository = repository;

  final CatalogRepository _repository;
  ViewState _state = ViewState.loading;
  List<Recipe> _catalog = const [];
  List<Recipe> _recipes = const [];
  String _query = '';
  String? _errorMessage;
  int _request = 0;
  bool _disposed = false;

  ViewState get state => _state;
  List<Recipe> get recipes => _recipes;
  String get query => _query;
  String? get errorMessage => _errorMessage;
  bool get hasQuery => normalizeRecipeName(_query).isNotEmpty;

  void updateQuery(String query) {
    if (_disposed || _query == query) return;
    _query = query;
    if (_state == ViewState.success) _filter();
    notifyListeners();
  }

  Future<void> load() async {
    if (_disposed) return;
    final request = ++_request;
    _errorMessage = null;
    if (_state != ViewState.loading) {
      _state = ViewState.loading;
      notifyListeners();
    }
    try {
      final catalog = await _repository.getAllRecipes();
      if (_disposed || request != _request) return;
      _catalog = List.unmodifiable(catalog);
      _filter();
      _state = ViewState.success;
    } on Object catch (error) {
      if (_disposed || request != _request) return;
      _catalog = const [];
      _recipes = const [];
      _errorMessage = error is AppFailure
          ? error.message
          : 'Tente novamente em instantes.';
      _state = ViewState.error;
    }
    notifyListeners();
  }

  void _filter() {
    final query = normalizeRecipeName(_query);
    _recipes = query.isEmpty
        ? _catalog
        : List.unmodifiable(
            _catalog.where(
              (recipe) => normalizeRecipeName(recipe.title).contains(query),
            ),
          );
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
