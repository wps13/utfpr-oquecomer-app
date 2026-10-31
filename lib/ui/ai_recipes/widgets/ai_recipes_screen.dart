import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../data/services/location/location_service.dart';
import '../../../data/services/permissions/permission_service.dart';
import '../../../domain/errors/app_failure.dart';
import '../../../domain/models/app_permission.dart';
import '../../../domain/models/recipe.dart';
import '../../../routing/routes.dart';
import '../../core/ui/permission_action.dart';
import '../../core/view_models/permission_viewmodel.dart';
import '../../core/themes/colors.dart';
import '../../core/themes/radius.dart';
import '../../core/themes/spacing.dart';
import '../view_models/ai_recipes_viewmodel.dart';
import 'detected_ingredients.dart';
import 'location_button.dart';
import 'location_permission_dialog.dart';
import 'location_unavailable_dialog.dart';

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
  }

  void _onServingsChanged() {
    final servings = int.tryParse(_servingsController.text);
    if (servings != null) {
      context.read<AiRecipesViewModel>().setServings(servings);
    }
  }

  void _changeServings(int delta) {
    final viewModel = context.read<AiRecipesViewModel>();
    final next = viewModel.servings + delta;
    if (next < AiRecipesViewModel.minServings) return;
    _servingsController
      ..text = '$next'
      ..selection = TextSelection.collapsed(offset: '$next'.length);
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
            Text(
              'O que tem na geladeira?',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.x1),
            Text(
              'Insira seus ingredientes e deixe a IA criar a magia culinária.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: AppSpacing.x5),
            _imageSelector(permissionViewModel),
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
            _servingsSelector(viewModel),
            if (viewModel.foodsDetected) ...[
              const SizedBox(height: AppSpacing.x4),
              DetectedIngredients(
                ingredients: viewModel.detectedIngredients,
                onRemove: viewModel.removeIngredient,
              ),
            ],
            const SizedBox(height: AppSpacing.x4),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: viewModel.canGenerateRecipe
                    ? viewModel.generateRecipe
                    : null,
                icon: viewModel.isLoading
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome),
                label: Text(
                  viewModel.isLoading
                      ? 'Processando...'
                      : viewModel.foodsDetected
                      ? 'Gerar receita'
                      : 'Detectar ingredientes',
                ),
              ),
            ),
            if (viewModel.errorMessage != null) ...[
              const SizedBox(height: AppSpacing.x3),
              _ErrorCard(
                message: viewModel.errorMessage!,
                onRetry: viewModel.generateRecipe,
              ),
            ],
            if (viewModel.recipe case final recipe?) ...[
              const SizedBox(height: AppSpacing.x5),
              _RecipeCard(recipe: recipe),
            ],
          ],
        ),
      ),
    );
  }

  Widget _servingsSelector(AiRecipesViewModel viewModel) => Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x2,
        vertical: AppSpacing.x3,
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: viewModel.isLoading ? null : () => _changeServings(-1),
            icon: const Icon(Icons.remove, size: 20),
            tooltip: 'Diminuir quantidade de pessoas',
            iconSize: 20,
            visualDensity: VisualDensity.compact,
          ),
          Expanded(
            child: TextField(
              controller: _servingsController,
              enabled: !viewModel.isLoading,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textAlign: TextAlign.center,
              decoration: const InputDecoration(
                isDense: true,
                labelText: 'Quantidade de pessoas',
                prefixIcon: Icon(Icons.people_outline, size: 20),
                prefixIconConstraints: BoxConstraints(
                  minWidth: 36,
                  minHeight: 36,
                ),
                contentPadding: EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
          IconButton(
            onPressed: viewModel.isLoading ? null : () => _changeServings(1),
            icon: const Icon(Icons.add, size: 20),
            tooltip: 'Aumentar quantidade de pessoas',
            iconSize: 20,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    ),
  );

  Widget _imageSelector(PermissionViewModel? permissionViewModel) {
    final imageBytes = context.watch<AiRecipesViewModel>().imageBytes;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.x3),
        child: Column(
          children: [
            if (imageBytes != null)
              ClipRRect(
                borderRadius: AppRadius.borderMd,
                child: Image.memory(
                  imageBytes,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              )
            else
              const Padding(
                padding: EdgeInsets.all(AppSpacing.x5),
                child: Icon(Icons.photo_camera_outlined, size: 48),
              ),
            const SizedBox(height: AppSpacing.x2),
            Row(
              children: [
                Expanded(
                  child: permissionViewModel == null
                      ? OutlinedButton.icon(
                          onPressed: null,
                          icon: const Icon(Icons.camera_alt_outlined),
                          label: const Text('Tirar foto'),
                        )
                      : PermissionAction(
                          viewModel: permissionViewModel,
                          permission: AppPermission.camera,
                          onAuthorized: (_) => _pickImage(ImageSource.camera),
                          builder: (context, onPressed) => OutlinedButton.icon(
                            onPressed: onPressed,
                            icon: const Icon(Icons.camera_alt_outlined),
                            label: const Text('Tirar foto'),
                          ),
                        ),
                ),
                const SizedBox(width: AppSpacing.x2),
                Expanded(
                  child: permissionViewModel == null
                      ? OutlinedButton.icon(
                          onPressed: null,
                          icon: const Icon(Icons.photo_library_outlined),
                          label: const Text('Galeria'),
                        )
                      : PermissionAction(
                          viewModel: permissionViewModel,
                          permission: AppPermission.photos,
                          onAuthorized: (_) => _pickImage(ImageSource.gallery),
                          builder: (context, onPressed) => OutlinedButton.icon(
                            onPressed: onPressed,
                            icon: const Icon(Icons.photo_library_outlined),
                            label: const Text('Galeria'),
                          ),
                        ),
                ),
              ],
            ),
          ],
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

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Card(
    color: AppColors.errorContainer,
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.x3),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.onErrorContainer),
          const SizedBox(width: AppSpacing.x2),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.onErrorContainer),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Tentar')),
        ],
      ),
    ),
  );
}

class _RecipeCard extends StatelessWidget {
  const _RecipeCard({required this.recipe});

  final Recipe recipe;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            recipe.title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (recipe.description.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.x2),
            Text(recipe.description),
          ],
          const SizedBox(height: AppSpacing.x2),
          Text(
            '${recipe.servings} '
            '${recipe.servings == 1 ? 'pessoa' : 'pessoas'}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.x4),
          Text(
            'Ingredientes',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          ...recipe.ingredients.map(
            (ingredient) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              minVerticalPadding: 0,
              visualDensity: const VisualDensity(vertical: -2),
              leading: const Icon(Icons.circle, size: 8),
              title: Text(
                ingredient,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.x3),
          Text(
            'Modo de preparo',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          ...recipe.steps.indexed.map(
            (entry) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                radius: 14,
                backgroundColor: AppColors.primaryFixed,
                child: Text('${entry.$1 + 1}'),
              ),
              title: Text(entry.$2),
            ),
          ),
        ],
      ),
    ),
  );
}
