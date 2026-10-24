import 'package:flutter/foundation.dart';

import '../../../data/repositories/ai_repository.dart';
import '../../../domain/errors/app_failure.dart';
import '../../../domain/models/ai_failure.dart';
import '../../../domain/models/recipe.dart';

class AiRecipesViewModel extends ChangeNotifier {
  static const defaultServings = 1;
  static const minServings = 1;

  AiRecipesViewModel({required AiRepository repository})
    // ignore: prefer_initializing_formals
    : _repository = repository;

  final AiRepository _repository;
  Uint8List? _imageBytes;
  String? _mimeType;
  Recipe? _recipe;
  String? _errorMessage;
  bool _loading = false;
  bool _foodsDetected = false;
  List<String> _detectedIngredients = const [];
  int _servings = defaultServings;
  bool _disposed = false;

  Uint8List? get imageBytes => _imageBytes;
  Recipe? get recipe => _recipe;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _loading;
  bool get hasImage => _imageBytes != null && _mimeType != null;
  bool get foodsDetected => _foodsDetected;
  List<String> get detectedIngredients =>
      List.unmodifiable(_detectedIngredients);
  int get servings => _servings;
  bool get canGenerateRecipe =>
      !_loading && (!_foodsDetected || _detectedIngredients.isNotEmpty);

  void setServings(int servings) {
    if (servings < minServings) return;
    _servings = servings;
    _recipe = null;
    _errorMessage = null;
    _notify();
  }

  void setImage({required Uint8List bytes, required String mimeType}) {
    _imageBytes = bytes;
    _mimeType = mimeType;
    _recipe = null;
    _errorMessage = null;
    _foodsDetected = false;
    _detectedIngredients = const [];
    _notify();
  }

  void setError(String message) {
    _setError(message);
  }

  Future<void> generateRecipe() async {
    if (!hasImage) {
      _debugLog('generateRecipe: nenhuma imagem selecionada');
      _setError('Selecione uma foto da galeria ou tire uma foto para começar.');
      return;
    }
    if (_loading || (_foodsDetected && _detectedIngredients.isEmpty)) {
      _debugLog('generateRecipe: requisição ignorada, já está carregando');
      return;
    }

    _setLoading();
    try {
      if (!_foodsDetected) {
        _debugLog(
          'generateRecipe: identificando alimentos '
          '(bytes=${_imageBytes!.length}, mime=$_mimeType)',
        );
        final foods = await _repository.identifyFoods(
          imageBytes: _imageBytes!,
          mimeType: _mimeType!,
        );
        if (foods.isEmpty) {
          throw const AiFailure(AiFailureKind.emptyResponse);
        }
        _detectedIngredients = foods;
        _foodsDetected = true;
        _debugLog('generateRecipe: alimentos identificados');
        return;
      }

      _debugLog('generateRecipe: gerando com ingredientes selecionados');
      _recipe = await _repository.generateRecipe(
        _detectedIngredients,
        servings: _servings,
      );
      _debugLog('generateRecipe: receita gerada com sucesso');
      _errorMessage = null;
    } on AiFailure catch (failure) {
      _debugLog('generateRecipe: AiFailure kind=${failure.kind.name}');
      _errorMessage = failure.message;
    } on AppFailure catch (failure) {
      _debugLog('generateRecipe: AppFailure ${failure.runtimeType}');
      _errorMessage = failure.message;
    } on Object catch (error, stackTrace) {
      _debugLog(
        'generateRecipe: erro não tratado ${error.runtimeType}',
        stackTrace,
      );
      _errorMessage = 'Não foi possível gerar a receita. Tente novamente.';
    } finally {
      _loading = false;
      _notify();
    }
  }

  void removeIngredient(String ingredient) {
    if (!_foodsDetected || _loading) return;
    _detectedIngredients = [
      for (final item in _detectedIngredients)
        if (item != ingredient) item,
    ];
    _recipe = null;
    _errorMessage = null;
    _notify();
  }

  void _setLoading() {
    _loading = true;
    _errorMessage = null;
    _recipe = null;
    _notify();
  }

  void _setError(String message) {
    _errorMessage = message;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _debugLog(String message, [StackTrace? stackTrace]) {
    if (!kDebugMode) return;
    debugPrint('[AiRecipesViewModel] $message');
    if (stackTrace != null) debugPrintStack(stackTrace: stackTrace);
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
