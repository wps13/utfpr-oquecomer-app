import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:o_que_comer_app/data/services/errors/error_reporter.dart';
import 'package:o_que_comer_app/data/services/voice/voice_capture_service.dart';
import 'package:o_que_comer_app/domain/errors/app_failure.dart';
import 'package:o_que_comer_app/domain/models/app_permission.dart';
import 'package:o_que_comer_app/domain/models/recipe.dart';
import 'package:o_que_comer_app/domain/models/voice_failure.dart';
import 'package:o_que_comer_app/ui/core/themes/theme.dart';
import 'package:o_que_comer_app/ui/hands_free_mode/view_models/hands_free_mode_viewmodel.dart';
import 'package:o_que_comer_app/ui/hands_free_mode/widgets/hands_free_mode_screen.dart';
import 'package:provider/provider.dart';

import '../../../../testing/fakes/fake_catalog_repository.dart';
import '../../../../testing/fakes/fake_favorites_repository.dart';
import '../../../../testing/fakes/fake_speech_service.dart';
import '../../../../testing/fakes/fake_voice_capture_service.dart';
import '../../../../testing/fakes/fake_voice_permissions.dart';

class _Permissions extends FakeVoicePermissions {
  int settingsCalls = 0;
  @override
  Future<bool> openSettings() async {
    settingsCalls++;
    return true;
  }
}

void main() {
  late FakeCatalogRepository catalog;
  late FakeVoiceCaptureService capture;
  late FakeSpeechService speech;
  late _Permissions permissions;

  setUp(() {
    catalog = FakeCatalogRepository()
      ..recipes = [
        Recipe(
          id: '1',
          title: 'Arroz com legumes',
          ingredients: ['Arroz'],
          steps: [
            'Lave o arroz.',
            'Refogue os legumes.',
            'Adicione água e cozinhe.',
          ],
          source: RecipeSource.catalog,
        ),
      ];
    capture = FakeVoiceCaptureService();
    speech = FakeSpeechService();
    permissions = _Permissions();
  });

  tearDown(() => unawaited(capture.dispose()));

  Future<void> pump(WidgetTester tester, {double scale = 1}) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: ChangeNotifierProvider(
          create: (_) => HandsFreeModeViewModel(
            recipeId: '1',
            catalogRepository: catalog,
            favoritesRepository: FakeFavoritesRepository(),
            capture: capture,
            speechService: speech,
            permissions: permissions,
            errorReporter: const DisabledErrorReporter(),
          ),
          child: const HandsFreeModeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows listening, current step and real reading completion', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Ouvindo'), findsOneWidget);
    expect(find.text('Passo 1 de 3'), findsOneWidget);
    expect(find.text('Lave o arroz.'), findsOneWidget);
    capture.emit('próximo passo');
    await tester.pumpAndSettle();
    expect(find.text('Passo 2 de 3'), findsOneWidget);
    expect(find.text('Lendo o passo'), findsOneWidget);
    expect(find.text('Pausar leitura'), findsOneWidget);
    expect(capture.state, VoiceCaptureState.suspended);
    speech.complete();
    await tester.pumpAndSettle();
    expect(find.text('Ouvindo'), findsOneWidget);
    expect(find.text('Ouvir passo'), findsOneWidget);
  });

  testWidgets('denied microphone explains failure and preserves manual steps', (
    tester,
  ) async {
    capture.startFailure = const VoiceFailure(
      VoiceFailureKind.microphoneDenied,
      permissionAccess: PermissionAccess.denied,
    );
    await pump(tester);
    expect(find.text('Modo por voz indisponível'), findsOneWidget);
    expect(
      find.textContaining('Permita o acesso ao microfone'),
      findsOneWidget,
    );
    await tester.ensureVisible(find.text('Próximo passo'));
    await tester.tap(find.text('Próximo passo'));
    await tester.pumpAndSettle();
    expect(find.text('Passo 2 de 3'), findsOneWidget);
    speech.complete();
    await tester.pumpAndSettle();
    expect(capture.state, VoiceCaptureState.failed);
    capture.startFailure = null;
    await tester.ensureVisible(find.text('Ativar comandos de voz'));
    await tester.tap(find.text('Ativar comandos de voz'));
    await tester.pumpAndSettle();
    expect(find.text('Ouvindo'), findsOneWidget);
  });

  testWidgets('permanent denial offers settings and retry after returning', (
    tester,
  ) async {
    capture.startFailure = const VoiceFailure(
      VoiceFailureKind.microphoneDenied,
      permissionAccess: PermissionAccess.permanentlyDenied,
    );
    await pump(tester);
    await tester.ensureVisible(find.text('Abrir configurações'));
    await tester.tap(find.text('Abrir configurações'));
    await tester.pumpAndSettle();
    expect(permissions.settingsCalls, 1);
    expect(find.text('Ativar comandos de voz'), findsOneWidget);
    expect(capture.state, VoiceCaptureState.stopped);
    capture.startFailure = null;
    await tester.tap(find.text('Ativar comandos de voz'));
    await tester.pumpAndSettle();
    expect(find.text('Ouvindo'), findsOneWidget);
  });

  testWidgets('unavailable recognizer reports a distinct explanation', (
    tester,
  ) async {
    capture.startFailure = const VoiceFailure(
      VoiceFailureKind.recognitionUnavailable,
    );
    await pump(tester);
    expect(
      find.textContaining('não está disponível neste dispositivo'),
      findsOneWidget,
    );
    expect(find.text('Abrir configurações'), findsNothing);
  });

  testWidgets('manual pause is available while microphone is suspended', (
    tester,
  ) async {
    await pump(tester);
    await tester.ensureVisible(find.text('Ouvir passo'));
    await tester.tap(find.text('Ouvir passo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pausar leitura'));
    await tester.pumpAndSettle();
    expect(find.text('Ouvindo'), findsOneWidget);
    expect(find.textContaining('Leitura pausada'), findsOneWidget);
  });

  testWidgets('load failure is recoverable and never starts microphone', (
    tester,
  ) async {
    catalog.loadRecipe = (_) async => throw const NoConnectionFailure();
    await pump(tester);
    expect(find.text('Não foi possível abrir a receita'), findsOneWidget);
    expect(capture.startCalls, 0);
    catalog.loadRecipe = null;
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.text('Ouvindo'), findsOneWidget);
  });

  testWidgets('empty recipe shows an explanation without starting voice', (
    tester,
  ) async {
    catalog.recipes = [
      Recipe(
        id: '1',
        title: 'Sem preparo',
        ingredients: ['Água'],
        steps: [],
        source: RecipeSource.catalog,
      ),
    ];
    await pump(tester);
    expect(find.text('Esta receita não tem passos de preparo'), findsOneWidget);
    expect(capture.startCalls, 0);
  });

  testWidgets('fits narrow screens and enlarged text without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pump(tester, scale: 1.8);
    await tester.ensureVisible(find.text('Próximo passo'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Comandos de voz'));
    await tester.tap(find.text('Comandos de voz'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
