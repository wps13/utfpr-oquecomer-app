import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../data/services/location/location_service.dart';
import '../../../data/services/permissions/permission_service.dart';
import '../../../domain/errors/app_failure.dart';
import '../../../domain/models/app_permission.dart';
import '../../../domain/models/recipe.dart';
import '../../../routing/routes.dart';
import '../../core/view_state.dart';
import '../../core/view_models/permission_viewmodel.dart';
import '../../core/themes/spacing.dart';
import '../../favorites/view_models/favorites_viewmodel.dart';
import '../view_models/ai_recipes_viewmodel.dart';
import 'detected_ingredients.dart';
import 'ai_recipes_header.dart';
import 'image_selector.dart';
import 'location_button.dart';
import 'location_permission_dialog.dart';
import 'location_unavailable_dialog.dart';
import 'recipe_action_button.dart';
import 'recipe_result.dart';
import 'servings_selector.dart';

class AiRecipesScreen extends StatefulWidget {
  const AiRecipesScreen({super.key});

  @override
  State<AiRecipesScreen> createState() => _AiRecipesScreenState();
}

class _AiRecipesScreenState extends State<AiRecipesScreen> {
  final _picker = ImagePicker();
  late final TextEditingController _servingsController;
  String? _location;
  bool _locationLoading = false;

  @override
  void initState() {
    super.initState();
    _servingsController = TextEditingController(
      text: '${AiRecipesViewModel.defaultServings}',
    );
    _servingsController.addListener(_onServingsChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final favorites = context.read<FavoritesViewModel?>();
      if (favorites?.state == ViewState.loading) {
        unawaited(favorites!.load());
      }
    });
  }

  void _onServingsChanged() {
    final servings = int.tryParse(_servingsController.text);
    if (servings != null) {
      context.read<AiRecipesViewModel>().setServings(servings);
    }
  }

  void _setServings(int servings) {
    if (servings < AiRecipesViewModel.minServings) return;
    _servingsController
      ..text = '$servings'
      ..selection = TextSelection.collapsed(offset: '$servings'.length);
  }

  @override
  void dispose() {
    _servingsController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source,
        // Reduz o payload enviado ao Gemini sem alterar a foto exibida.
        maxWidth: 1024,
        imageQuality: 85,
      );
      if (file == null) {
        _debugLog('pickImage: usuário cancelou a seleção');
        return;
      }
      final bytes = await file.readAsBytes();
      final mimeType = _mimeTypeFor(file);
      if (mimeType == null) {
        _debugLog('pickImage: formato não suportado');
        if (!mounted) return;
        context.read<AiRecipesViewModel>().setError(
          'Escolha uma imagem JPEG, PNG ou WebP.',
        );
        return;
      }
      if (!mounted) return;
      context.read<AiRecipesViewModel>().setImage(
        bytes: bytes,
        mimeType: mimeType,
      );
      _debugLog(
        'pickImage: imagem carregada (bytes=${bytes.length}, mime=$mimeType)',
      );
    } on Object catch (error, stackTrace) {
      _debugLog('pickImage: erro ${error.runtimeType}', stackTrace);
      if (mounted) {
        context.read<AiRecipesViewModel>().setError(
          'Não foi possível carregar a imagem. Tente novamente.',
        );
      }
    }
  }

  void _debugLog(String message, [StackTrace? stackTrace]) {
    if (!kDebugMode) return;
    debugPrint('[AiRecipesScreen] $message');
    if (stackTrace != null) debugPrintStack(stackTrace: stackTrace);
  }

  String? _mimeTypeFor(XFile file) {
    final mimeType = file.mimeType?.toLowerCase();
    if (const {'image/jpeg', 'image/png', 'image/webp'}.contains(mimeType)) {
      return mimeType;
    }
    final extension = file.name.split('.').last.toLowerCase();
    return switch (extension) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<AiRecipesViewModel>();
    final favorites = context.watch<FavoritesViewModel?>();
    final permissionService = context.read<PermissionService?>();
    final permissionViewModel = permissionService == null
        ? null
        : PermissionViewModel(permissionService: permissionService);
    final locationService = context.read<LocationService?>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Receita com IA'),
        leading: BackButton(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(Routes.home);
            }
          },
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.x4,
            AppSpacing.x3,
            AppSpacing.x4,
            AppSpacing.x8,
          ),
          children: [
            const AiRecipesHeader(),
            const SizedBox(height: AppSpacing.x5),
            ImageSelector(
              imageBytes: viewModel.imageBytes,
              permissionViewModel: permissionViewModel,
              onPickImage: _pickImage,
            ),
            const SizedBox(height: AppSpacing.x2),
            LocationButton(
              location: _location,
              loading: _locationLoading,
              onPressed:
                  permissionViewModel != null &&
                      locationService != null &&
                      !_locationLoading
                  ? () => _requestLocation(permissionViewModel, locationService)
                  : null,
            ),
            const SizedBox(height: AppSpacing.x4),
            ServingsSelector(
              controller: _servingsController,
              servings: viewModel.servings,
              loading: viewModel.isLoading,
              onChange: _setServings,
            ),
            if (viewModel.foodsDetected) ...[
              const SizedBox(height: AppSpacing.x4),
              DetectedIngredients(
                ingredients: viewModel.detectedIngredients,
                onRemove: viewModel.removeIngredient,
              ),
            ],
            const SizedBox(height: AppSpacing.x4),
            RecipeActionButton(
              loading: viewModel.isLoading,
              foodsDetected: viewModel.foodsDetected,
              enabled: viewModel.canGenerateRecipe,
              onPressed: viewModel.generateRecipe,
            ),
            if (viewModel.errorMessage != null) ...[
              const SizedBox(height: AppSpacing.x3),
              RecipeErrorCard(
                message: viewModel.errorMessage!,
                onRetry: viewModel.generateRecipe,
              ),
            ],
            if (viewModel.recipe case final recipe?) ...[
              const SizedBox(height: AppSpacing.x5),
              RecipeResultCard(
                recipe: recipe,
                showFavorite: favorites != null,
                isFavorite:
                    favorites?.favorites.any((f) => f.id == recipe.id) ?? false,
                onFavorite:
                    favorites == null || favorites.state == ViewState.loading
                    ? null
                    : () => _toggleFavorite(recipe),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _toggleFavorite(Recipe recipe) async {
    final favorites = context.read<FavoritesViewModel?>();
    if (favorites == null) return;
    final isFavorite = favorites.favorites.any((f) => f.id == recipe.id);
    if (isFavorite) {
      await favorites.remove(recipe.id);
    } else {
      await favorites.saveRecipe(recipe);
    }
    if (!mounted) return;
    final failed = favorites.state == ViewState.error;
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            failed
                ? 'Não foi possível atualizar seus favoritos. Tente novamente.'
                : isFavorite
                ? 'Receita removida dos favoritos'
                : 'Receita adicionada aos favoritos',
          ),
        ),
      );
  }

  Future<void> _requestLocation(
    PermissionViewModel permissionViewModel,
    LocationService locationService,
  ) async {
    if (_locationLoading) return;
    setState(() => _locationLoading = true);
    try {
      var access = await permissionViewModel.check(
        AppPermission.locationWhenInUse,
      );
      if (!mounted) return;
      if (access == PermissionAccess.denied) {
        final confirmed = await LocationPermissionDialog.show(context);
        if (confirmed == false && mounted) {
          await LocationUnavailableDialog.show(
            context,
            const LocationPermissionDeniedFailure(),
          );
        }
        if (confirmed != true || !mounted) return;
        access = await permissionViewModel.request(
          AppPermission.locationWhenInUse,
        );
        if (!mounted) return;
      }
      if (!access.isAuthorized) {
        await LocationUnavailableDialog.show(
          context,
          const LocationPermissionDeniedFailure(),
        );
        return;
      }

      final location = await locationService.getCurrentLocation();
      if (mounted) {
        setState(() => _location = location);
        context.read<AiRecipesViewModel>().setLocation(location);
      }
    } on LocationFailure catch (failure) {
      if (mounted) {
        setState(() => _location = null);
        context.read<AiRecipesViewModel>().setLocation(null);
        await LocationUnavailableDialog.show(context, failure);
      }
    } finally {
      if (mounted) setState(() => _locationLoading = false);
    }
  }
}
