// Repositórios privados: o padrão das ViewModels não expõe dependências.
// ignore_for_file: prefer_initializing_formals

import 'package:flutter/foundation.dart';

import '../../../data/repositories/catalog_repository.dart';
import '../../../data/repositories/favorites_repository.dart';
import '../../../domain/errors/app_failure.dart';
import '../../../domain/models/recipe.dart';
import '../../core/view_state.dart';
import 'recipe_text_format.dart';

/// Carrega a receita pelo id. O catálogo é a fonte principal; se ele falhar
/// (sem internet, receita gerada por IA, etc.), usa a cópia salva nos
/// favoritos antes de exibir o erro.
class RecipeDetailsViewModel extends ChangeNotifier {
  RecipeDetailsViewModel({
    required this.recipeId,
    required CatalogRepository catalogRepository,
    required FavoritesRepository favoritesRepository,
  }) : _catalogRepository = catalogRepository,
       _favoritesRepository = favoritesRepository;

  final String recipeId;
  final CatalogRepository _catalogRepository;
  final FavoritesRepository _favoritesRepository;

  ViewState _state = ViewState.loading;
  Recipe? _recipe;
  String? _errorMessage;
  int _request = 0;
  bool _disposed = false;

  ViewState get state => _state;
  Recipe? get recipe => _recipe;
  String? get errorMessage => _errorMessage;

  /// A receita não existe (404 ou id inválido): tentar de novo não resolve.
  bool get isNotFound => _isNotFound;
  bool _isNotFound = false;

  /// Ingredientes um por item, mesmo quando a API envia um texto único.
  List<String> get ingredients => _ingredients;

  /// Passos um por item, sem a numeração que vem no texto da API.
  List<String> get steps => _steps;

  List<String> _ingredients = const [];
  List<String> _steps = const [];

  /// Chamar do `initState` (após o primeiro frame) ou do botão de tentar
  /// novamente.
  Future<void> load() async {
    if (_disposed) return;
    final request = ++_request;
    _errorMessage = null;
    _isNotFound = false;
    if (_state != ViewState.loading) {
      _state = ViewState.loading;
      notifyListeners();
    }

    Recipe? recipe;
    Object? catalogError;
    try {
      recipe = await _catalogRepository.getRecipe(recipeId);
    } on Object catch (error) {
      catalogError = error;
      recipe = await _findInFavorites();
    }
    if (_disposed || request != _request) return;

    if (recipe != null) {
      _recipe = recipe;
      _ingredients = List.unmodifiable(splitIngredients(recipe.ingredients));
      _steps = List.unmodifiable(splitSteps(recipe.steps));
      _state = ViewState.success;
    } else {
      _recipe = null;
      _ingredients = const [];
      _steps = const [];
      _isNotFound =
          catalogError is InvalidInputFailure ||
          (catalogError is ClientFailure && catalogError.isNotFound);
      _errorMessage = _isNotFound
          ? 'Ela pode ter sido removida do catálogo ou o link está incorreto.'
          : catalogError is AppFailure
          ? catalogError.message
          : 'Tente novamente em instantes.';
      _state = ViewState.error;
    }
    notifyListeners();
  }

  Future<Recipe?> _findInFavorites() async {
    try {
      final favorites = await _favoritesRepository.getFavorites();
      for (final favorite in favorites) {
        if (favorite.id == recipeId) return favorite;
      }
    } on Object {
      // Sem favoritos disponíveis: prevalece o erro do catálogo.
    }
    return null;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
