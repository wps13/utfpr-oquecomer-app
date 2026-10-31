import 'package:flutter/foundation.dart';

import '../../../data/repositories/catalog_repository.dart';
import '../../../domain/errors/app_failure.dart';
import '../../../domain/models/recipe_category.dart';
import '../../core/view_state.dart';

class HomeViewModel extends ChangeNotifier {
  HomeViewModel({required CatalogRepository repository})
    // ignore: prefer_initializing_formals
    : _repository = repository;

  final CatalogRepository _repository;
  ViewState _state = ViewState.loading;
  List<RecipeCategory> _categories = const [];
  String? _errorMessage;
  int _request = 0;
  bool _disposed = false;

  ViewState get state => _state;
  List<RecipeCategory> get categories => _categories;
  String? get errorMessage => _errorMessage;

  Future<void> load() async {
    if (_disposed) return;
    final request = ++_request;
    _errorMessage = null;
    if (_state != ViewState.loading) {
      _state = ViewState.loading;
      notifyListeners();
    }
    try {
      final categories = await _repository.getCategories();
      if (_disposed || request != _request) return;
      _categories = List.unmodifiable(categories);
      _state = ViewState.success;
    } on Object catch (error) {
      if (_disposed || request != _request) return;
      _categories = const [];
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
