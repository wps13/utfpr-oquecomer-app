import 'dart:async';
import 'dart:typed_data';

import 'package:o_que_comer_app/data/services/errors/error_reporter.dart';
import 'package:o_que_comer_app/data/services/permissions/permission_service.dart';
import 'package:o_que_comer_app/data/services/voice/voice_capture_service.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:o_que_comer_app/data/repositories/ai_repository.dart';
import 'package:o_que_comer_app/data/repositories/catalog_repository.dart';
import 'package:o_que_comer_app/data/repositories/favorites_repository.dart';
import 'package:o_que_comer_app/data/services/speech/speech_service.dart';
import 'package:o_que_comer_app/domain/models/recipe.dart';
import 'package:o_que_comer_app/routing/router.dart';
import 'package:o_que_comer_app/routing/routes.dart';
import 'package:o_que_comer_app/ui/favorites/view_models/favorites_viewmodel.dart';
import 'package:o_que_comer_app/ui/hands_free_mode/view_models/hands_free_mode_viewmodel.dart';
import 'package:o_que_comer_app/ui/hands_free_mode/widgets/hands_free_mode_screen.dart';
import 'package:provider/provider.dart';

import '../../testing/fakes/fake_catalog_repository.dart';
import '../../testing/fakes/fake_speech_service.dart';
import '../../testing/fakes/fake_voice_capture_service.dart';
import '../../testing/fakes/fake_voice_permissions.dart';

class _ImmediateFavoritesRepository implements FavoritesRepository {
  @override
  Future<List<Recipe>> getFavorites() async => const [];

  @override
  Future<void> save(Recipe favorite) async {}

  @override
  Future<void> add(Recipe favorite) async {}

  @override
  Future<void> remove(String id) async {}

  @override
  Future<bool> isFavorite(String id) async => false;
}

class _ImmediateAiRepository implements AiRepository {
  @override
  Future<Recipe> generateRecipe(
    List<String> ingredients, {
    int servings = 2,
    String? location,
  }) => throw UnimplementedError();

  @override
  Future<List<String>> identifyFoods({
    required Uint8List imageBytes,
    required String mimeType,
  }) => throw UnimplementedError();
}

void main() {
  late FavoritesViewModel favoritesViewModel;
  late FakeSpeechService speechService;
  late FakeVoiceCaptureService capture;

  setUp(() {
    router.go(Routes.home);
    speechService = FakeSpeechService();
    capture = FakeVoiceCaptureService();
    favoritesViewModel = FavoritesViewModel(
      repository: _ImmediateFavoritesRepository(),
    );
  });

  tearDown(() {
    favoritesViewModel.dispose();
    unawaited(capture.dispose());
  });

  Future<void> pumpRouter(WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: favoritesViewModel,
        child: Provider<AiRepository>.value(
          value: _ImmediateAiRepository(),
          child: MultiProvider(
            providers: [
              Provider<FavoritesRepository>.value(
                value: _ImmediateFavoritesRepository(),
              ),
              Provider<SpeechService>.value(value: speechService),
              Provider<VoiceCaptureService>.value(value: capture),
              Provider<PermissionService>.value(value: FakeVoicePermissions()),
              Provider<ErrorReporter>.value(
                value: const DisabledErrorReporter(),
              ),
            ],
            child: Provider<CatalogRepository>(
              create: (_) => FakeCatalogRepository()
                ..recipes = [
                  Recipe(
                    id: '42',
                    title: 'Bolo de cenoura',
                    ingredients: ['Cenoura'],
                    steps: ['Asse.'],
                    source: RecipeSource.catalog,
                  ),
                ],
              child: MaterialApp.router(routerConfig: router),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> goTo(WidgetTester tester, String location) async {
    router.go(location);
    await tester.pumpAndSettle();
  }

  testWidgets('starts at home inside the main shell', (tester) async {
    await pumpRouter(tester);

    expect(find.text('Categorias'), findsOneWidget);
    expect(find.text('Gerar com IA'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      0,
    );
  });

  testWidgets('opens the AI recipe screen from the home action', (
    tester,
  ) async {
    await pumpRouter(tester);

    await tester.tap(find.text('Gerar com IA'));
    await tester.pumpAndSettle();

    expect(router.routeInformationProvider.value.uri.path, Routes.aiRecipe);
    expect(find.text('O que tem na geladeira?'), findsOneWidget);
  });

  testWidgets('maps shell routes to their screens', (tester) async {
    await pumpRouter(tester);

    final shellRoutes = {
      Routes.aiRecipe: 'O que tem na geladeira?',
      Routes.inventory: 'Despensa',
      Routes.search: 'Buscar receitas',
    };

    for (final entry in shellRoutes.entries) {
      await goTo(tester, entry.key);
      expect(find.text(entry.value), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
    }
  });

  testWidgets('maps catalog outside the shell', (tester) async {
    await pumpRouter(tester);
    await goTo(tester, Routes.catalog);

    expect(find.text('Catálogo'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('selecting a bottom navigation destination changes routes', (
    tester,
  ) async {
    await pumpRouter(tester);

    await tester.tap(find.text('Buscar'));
    await tester.pumpAndSettle();
    expect(find.text('Buscar receitas'), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      1,
    );

    await tester.tap(find.text('Favoritos').last);
    await tester.pumpAndSettle();
    expect(find.text('Nenhum favorito ainda'), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      2,
    );
  });

  testWidgets('redirects the recipes collection to the default recipe', (
    tester,
  ) async {
    await pumpRouter(tester);
    await goTo(tester, Routes.recipes);

    expect(
      router.routeInformationProvider.value.uri.path,
      Routes.recipeDetails('1'),
    );
    // A receita padrão não existe no catálogo falso.
    expect(find.text('Receita não encontrada'), findsOneWidget);
  });

  testWidgets('opens the requested recipe and its hands-free child route', (
    tester,
  ) async {
    await pumpRouter(tester);
    await goTo(tester, Routes.recipeDetails('42'));

    await tester.tap(find.text('Iniciar'));
    await tester.pumpAndSettle();

    expect(find.text('Modo mãos livres'), findsOneWidget);
    expect(find.text('Passo 1 de 1'), findsOneWidget);
    expect(find.text('Ouvindo'), findsOneWidget);
    expect(find.text('Modo de preparo'), findsNothing);
  });

  testWidgets('leaving the hands-free screen stops the reading', (
    tester,
  ) async {
    await pumpRouter(tester);
    await goTo(tester, Routes.recipeDetails('42'));
    await tester.tap(find.text('Iniciar'));
    await tester.pumpAndSettle();

    final mode = tester
        .element(find.byType(HandsFreeModeScreen))
        .read<HandsFreeModeViewModel>();
    unawaited(mode.readStep());
    await tester.pumpAndSettle();
    expect(speechService.spoken, ['Asse.']);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.byType(HandsFreeModeScreen), findsNothing);
    expect(speechService.stopCalls, greaterThanOrEqualTo(1));
    expect(capture.state, VoiceCaptureState.stopped);
  });

  testWidgets('spoken exit returns to the recipe and stops the microphone', (
    tester,
  ) async {
    await pumpRouter(tester);
    await goTo(tester, Routes.recipeDetails('42'));
    await tester.tap(find.text('Iniciar'));
    await tester.pumpAndSettle();
    capture.emit('sair do modo');
    await tester.pumpAndSettle();
    expect(find.byType(HandsFreeModeScreen), findsNothing);
    expect(find.text('Modo de preparo'), findsOneWidget);
    expect(capture.state, VoiceCaptureState.stopped);
  });

  testWidgets('covering the mode with another route stops capture and audio', (
    tester,
  ) async {
    await pumpRouter(tester);
    await goTo(tester, Routes.handsFreeMode('42'));
    final context = tester.element(find.byType(HandsFreeModeScreen));
    unawaited(context.read<HandsFreeModeViewModel>().readStep());
    await tester.pumpAndSettle();
    final navigator = Navigator.of(context);
    unawaited(
      navigator.push<void>(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Outra tela')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(capture.state, VoiceCaptureState.stopped);
    navigator.pop();
    await tester.pumpAndSettle();
    expect(capture.state, VoiceCaptureState.stopped);
    expect(find.text('Ativar comandos de voz'), findsOneWidget);
  });

  testWidgets('search result opens the selected recipe details', (
    tester,
  ) async {
    await pumpRouter(tester);
    await goTo(tester, Routes.search);

    await tester.ensureVisible(find.text('Bolo de cenoura'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bolo de cenoura'));
    await tester.pumpAndSettle();

    expect(find.text('Modo de preparo'), findsOneWidget);
  });
}
