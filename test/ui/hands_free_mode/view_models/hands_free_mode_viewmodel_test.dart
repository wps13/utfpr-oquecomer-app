import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:o_que_comer_app/data/services/errors/error_reporter.dart';
import 'package:o_que_comer_app/data/services/voice/voice_capture_service.dart';
import 'package:o_que_comer_app/domain/errors/app_failure.dart';
import 'package:o_que_comer_app/domain/models/app_permission.dart';
import 'package:o_que_comer_app/domain/models/recipe.dart';
import 'package:o_que_comer_app/domain/models/voice_failure.dart';
import 'package:o_que_comer_app/ui/core/view_state.dart';
import 'package:o_que_comer_app/ui/hands_free_mode/view_models/hands_free_mode_viewmodel.dart';

import '../../../../testing/fakes/fake_catalog_repository.dart';
import '../../../../testing/fakes/fake_favorites_repository.dart';
import '../../../../testing/fakes/fake_speech_service.dart';
import '../../../../testing/fakes/fake_screen_wake_lock_service.dart';
import '../../../../testing/fakes/fake_voice_capture_service.dart';
import '../../../../testing/fakes/fake_voice_permissions.dart';

class _SlowSpeech extends FakeSpeechService {
  final started = Completer<void>();
  @override
  Future<void> speak(String text) => started.future;
}

class _SlowStopSpeech extends FakeSpeechService {
  Completer<void>? stopping;
  @override
  Future<void> stop() async {
    await super.stop();
    await stopping?.future;
  }
}

class _SlowWakeLock extends FakeScreenWakeLockService {
  final ready = Completer<void>();

  @override
  Future<void> enable() async {
    await ready.future;
    await super.enable();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeVoiceCaptureService capture;
  late FakeSpeechService speech;
  late FakeCatalogRepository catalog;
  late FakeFavoritesRepository favorites;
  late FakeVoicePermissions permissions;
  late FakeScreenWakeLockService wakeLock;
  late HandsFreeModeViewModel vm;

  Recipe recipe({List<String>? steps}) => Recipe(
    id: '42',
    title: 'Arroz',
    ingredients: ['Arroz'],
    steps: steps ?? ['Lave o arroz.', 'Adicione água.', 'Cozinhe.'],
    source: RecipeSource.catalog,
  );

  HandsFreeModeViewModel create({
    FakeSpeechService? reader,
    FakeScreenWakeLockService? lock,
  }) => HandsFreeModeViewModel(
    recipeId: '42',
    catalogRepository: catalog,
    favoritesRepository: favorites,
    capture: capture,
    wakeLock: lock ?? wakeLock,
    speechService: reader ?? speech,
    permissions: permissions,
    errorReporter: const DisabledErrorReporter(),
  );

  Future<void> flush() => Future<void>.delayed(Duration.zero);

  setUp(() {
    capture = FakeVoiceCaptureService();
    speech = FakeSpeechService();
    catalog = FakeCatalogRepository()..recipes = [recipe()];
    favorites = FakeFavoritesRepository();
    permissions = FakeVoicePermissions();
    wakeLock = FakeScreenWakeLockService();
    vm = create();
  });

  tearDown(() async {
    vm.dispose();
    await flush();
    await capture.dispose();
  });

  test('microphone starts only after entering a valid recipe', () async {
    expect(capture.startCalls, 0);
    await vm.load();
    expect(vm.state, ViewState.success);
    expect(vm.recipeTitle, 'Arroz');
    expect(vm.currentStep, 'Lave o arroz.');
    expect(capture.startCalls, 1);
    expect(capture.state, VoiceCaptureState.listening);
    expect(speech.spoken, isEmpty);
  });

  test(
    'spoken next, previous and synonyms execute the recipe actions',
    () async {
      await vm.load();
      capture.emit('AVANÇAR!');
      await flush();
      expect(vm.stepIndex, 1);
      expect(speech.spoken.last, 'Adicione água.');
      expect(capture.state, VoiceCaptureState.suspended);
      speech.complete();
      await flush();
      capture.emit('passo anterior');
      await flush();
      expect(vm.stepIndex, 0);
      expect(speech.spoken.last, 'Lave o arroz.');
      speech.complete();
      await flush();
      capture.emit('continuar');
      await flush();
      expect(speech.spoken.last, 'Lave o arroz.');
    },
  );

  test('pause command keeps the current step and permits continue', () async {
    await vm.load();
    capture.emit('parar');
    await flush();
    expect(vm.stepIndex, 0);
    expect(vm.feedback, contains('pausada'));
    expect(capture.state, VoiceCaptureState.listening);
    capture.emit('continuar');
    await flush();
    expect(speech.spoken, ['Lave o arroz.']);
  });

  test('unknown phrases and reading audio do not change the step', () async {
    await vm.load();
    capture.emit('hoje vou preparar arroz');
    await flush();
    expect(speech.spoken, isEmpty);
    final reading = vm.readStep();
    await flush();
    // speak() já retornou, mas o áudio ainda está tocando.
    expect(vm.isReading, isTrue);
    expect(capture.state, VoiceCaptureState.suspended);
    capture.emit('próximo passo');
    await flush();
    expect(vm.stepIndex, 0);
    speech.complete();
    await reading;
    expect(capture.state, VoiceCaptureState.listening);
    expect(vm.isReading, isFalse);
  });

  test(
    'manual pause releases playback and continue restarts the step',
    () async {
      await vm.load();
      final reading = vm.readStep();
      await flush();
      await vm.pauseReading();
      await reading;
      expect(vm.isReading, isFalse);
      expect(capture.state, VoiceCaptureState.listening);
      capture.emit('continuar');
      await flush();
      expect(speech.spoken, ['Lave o arroz.', 'Lave o arroz.']);
    },
  );

  test(
    'replacing reading keeps capture suspended until the new audio ends',
    () async {
      await vm.load();
      final states = <VoiceCaptureState>[];
      final subscription = capture.states.listen(states.add);
      final first = vm.readStep();
      await flush();
      final second = vm.nextStep();
      await flush();
      await first;
      expect(capture.state, VoiceCaptureState.suspended);
      expect(states, isNot(contains(VoiceCaptureState.listening)));
      speech.complete();
      await second;
      expect(capture.state, VoiceCaptureState.listening);
      await subscription.cancel();
    },
  );

  test('rapid replacements release every old playback suspension', () async {
    await vm.load();
    final first = vm.readStep();
    await flush();
    final second = vm.nextStep();
    final third = vm.nextStep();
    await flush();
    await Future.wait([first, second]);
    expect(vm.stepIndex, 2);
    expect(speech.spoken.last, 'Cozinhe.');
    expect(capture.state, VoiceCaptureState.suspended);
    speech.complete();
    await third;
    expect(capture.state, VoiceCaptureState.listening);
  });

  test('pause waits for native stop before restarting capture', () async {
    vm.dispose();
    final slow = _SlowStopSpeech();
    vm = create(reader: slow);
    await vm.load();
    final reading = vm.readStep();
    await flush();
    slow.stopping = Completer<void>();
    final pause = vm.pauseReading();
    await flush();
    await reading;
    expect(capture.state, VoiceCaptureState.suspended);
    slow.stopping!.complete();
    await pause;
    expect(capture.state, VoiceCaptureState.listening);
  });

  test(
    'exit cancels a pending speech startup and never resumes capture',
    () async {
      vm.dispose();
      final slow = _SlowSpeech();
      vm = create(reader: slow);
      await vm.load();
      final reading = vm.readStep();
      await flush();
      vm.exit();
      await reading;
      expect(vm.exitRequested, isTrue);
      expect(capture.state, VoiceCaptureState.stopped);
      slow.started.complete();
      await flush();
      expect(capture.state, VoiceCaptureState.stopped);
    },
  );

  for (final phrase in ['sair', 'sair do modo']) {
    test('voice "$phrase" stops the mode', () async {
      await vm.load();
      capture.emit(phrase);
      await flush();
      expect(vm.exitRequested, isTrue);
      expect(capture.state, VoiceCaptureState.stopped);
    });
  }

  test('steps are bounded and the last step remains visible', () async {
    await vm.load();
    await vm.previousStep();
    expect(vm.feedback, contains('primeiro passo'));
    expect(speech.spoken, isEmpty);
    for (var i = 0; i < 2; i++) {
      final next = vm.nextStep();
      await flush();
      speech.complete();
      await next;
    }
    await vm.nextStep();
    expect(vm.stepIndex, 2);
    expect(vm.hasNext, isFalse);
    expect(vm.feedback, contains('último passo'));
  });

  test(
    'denied permission leaves manual controls available and allows retry',
    () async {
      capture.startFailure = const VoiceFailure(
        VoiceFailureKind.microphoneDenied,
        permissionAccess: PermissionAccess.denied,
      );
      await vm.load();
      expect(vm.voiceFailure?.kind, VoiceFailureKind.microphoneDenied);
      final manual = vm.nextStep();
      await flush();
      expect(vm.stepIndex, 1);
      speech.complete();
      await manual;
      capture.startFailure = null;
      await vm.startVoice();
      expect(vm.voiceFailure, isNull);
      expect(capture.state, VoiceCaptureState.listening);
    },
  );

  test(
    'speech failure resumes capture and shows a recoverable message',
    () async {
      await vm.load();
      speech.failure = const SpeechEngineUnavailableFailure();
      await vm.readStep();
      expect(vm.readingError, contains('não está disponível'));
      expect(vm.isReading, isFalse);
      expect(capture.state, VoiceCaptureState.listening);
    },
  );

  test(
    'background and a covered route stop audio without automatic restart',
    () async {
      await vm.load();
      final reading = vm.readStep();
      await flush();
      vm.didChangeAppLifecycleState(AppLifecycleState.hidden);
      await reading;
      expect(capture.state, VoiceCaptureState.stopped);
      vm.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await flush();
      expect(capture.startCalls, 1);
      await vm.startVoice();
      vm.setVisible(visible: false);
      expect(capture.state, VoiceCaptureState.stopped);
      vm.setVisible(visible: true);
      expect(capture.startCalls, 2);
    },
  );

  test('dispose releases a pending playback hold', () async {
    await vm.load();
    final reading = vm.readStep();
    await flush();
    vm.dispose();
    await reading;
    expect(capture.state, VoiceCaptureState.stopped);
    // Nova tela consegue escutar; nenhuma suspensão ficou retida.
    vm = create();
    await vm.load();
    expect(capture.state, VoiceCaptureState.listening);
  });

  test('does not start voice after leaving while recipe is loading', () async {
    final pending = Completer<Recipe>();
    catalog.loadRecipe = (_) => pending.future;
    final loading = vm.load();
    await flush();
    vm.setVisible(visible: false);
    pending.complete(recipe());
    await loading;
    expect(capture.startCalls, 0);
  });

  test('invalid recipe and empty steps never request microphone', () async {
    catalog.recipes = [];
    await vm.load();
    expect(vm.isNotFound, isTrue);
    expect(capture.startCalls, 0);
    catalog.recipes = [recipe(steps: [])];
    await vm.load();
    expect(vm.state, ViewState.success);
    expect(vm.steps, isEmpty);
    expect(capture.startCalls, 0);
  });

  test(
    'wake lock stays enabled through reading and is released on exit',
    () async {
      await vm.load();
      expect(wakeLock.enabled, isTrue);
      final reading = vm.readStep();
      await flush();
      expect(wakeLock.enabled, isTrue);
      speech.complete();
      await reading;
      expect(wakeLock.enabled, isTrue);
      vm.exit();
      await flush();
      expect(wakeLock.enabled, isFalse);
    },
  );

  test(
    'leaving during wake lock startup never starts the microphone later',
    () async {
      vm.dispose();
      final slow = _SlowWakeLock();
      vm = create(lock: slow);
      final loading = vm.load();
      await flush();
      vm.exit();
      slow.ready.complete();
      await loading;
      expect(capture.startCalls, 0);
      expect(capture.state, VoiceCaptureState.stopped);
      expect(slow.enabled, isFalse);
    },
  );

  test('saved recipe remains available when the catalog fails', () async {
    catalog.loadRecipe = (_) async => throw const NoConnectionFailure();
    favorites.items.add(recipe());
    await vm.load();
    expect(vm.state, ViewState.success);
    expect(vm.steps.length, 3);
  });
}
