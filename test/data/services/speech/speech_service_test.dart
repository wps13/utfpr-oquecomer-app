import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:o_que_comer_app/data/services/speech/speech_service.dart';
import 'package:o_que_comer_app/domain/errors/app_failure.dart';
import 'package:o_que_comer_app/domain/models/speech_status.dart';

class FakeTtsEngine implements TtsEngine {
  void Function(TtsEvent event)? _handler;
  final calls = <String>[];
  bool hasEngine = true;
  bool languageAvailable = true;
  bool speakResult = true;
  bool pauseResult = true;
  Exception? initializeError;
  Completer<void>? initializeGate;
  Completer<void>? speakGate;

  void emit(TtsEvent event) => _handler!(event);

  List<String> get spoken => [
    for (final call in calls)
      if (call.startsWith('speak:')) call.substring('speak:'.length),
  ];

  @override
  void setEventHandler(void Function(TtsEvent event) handler) =>
      _handler = handler;

  @override
  Future<bool> initialize() async {
    calls.add('initialize');
    await initializeGate?.future;
    final error = initializeError;
    if (error != null) throw error;
    return hasEngine;
  }

  @override
  Future<bool> setLanguage(String language) async {
    calls.add('setLanguage:$language');
    return languageAvailable;
  }

  @override
  Future<void> setSpeechRate(double rate) async =>
      calls.add('setSpeechRate:$rate');

  @override
  Future<void> setPitch(double pitch) async => calls.add('setPitch:$pitch');

  @override
  Future<bool> speak(String text) async {
    calls.add('speak:$text');
    await speakGate?.future;
    return speakResult;
  }

  @override
  Future<bool> pause() async {
    calls.add('pause');
    return pauseResult;
  }

  @override
  Future<void> stop() async => calls.add('stop');
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  late FakeTtsEngine engine;
  late DeviceSpeechService service;
  late List<SpeechStatus> statuses;

  setUp(() {
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    engine = FakeTtsEngine();
    service = DeviceSpeechService(
      engine: engine,
      timeout: const Duration(milliseconds: 50),
    );
    statuses = [];
    service.status.addListener(() => statuses.add(service.status.value));
  });

  tearDown(() => service.dispose());

  test('configures Brazilian Portuguese, rate and pitch once', () async {
    await service.speak('Passo 1');
    await service.speak('Passo 2');

    expect(engine.calls.where((c) => c == 'initialize'), hasLength(1));
    expect(engine.calls.take(4), [
      'initialize',
      'setLanguage:pt-BR',
      'setSpeechRate:0.5',
      'setPitch:1.0',
    ]);
    expect(engine.spoken, ['Passo 1', 'Passo 2']);
  });

  test('applies a custom configuration', () async {
    final custom = DeviceSpeechService(
      engine: engine,
      config: const SpeechConfig(
        language: 'pt-PT',
        speechRate: 0.4,
        pitch: 1.2,
      ),
    );
    addTearDown(custom.dispose);

    await custom.speak('Olá');

    expect(
      engine.calls,
      containsAll(['setLanguage:pt-PT', 'setSpeechRate:0.4', 'setPitch:1.2']),
    );
  });

  test(
    'speaks the trimmed text and reports speaking until completion',
    () async {
      await service.speak('  Pique a cebola.  ');

      expect(engine.spoken, ['Pique a cebola.']);
      expect(service.status.value, SpeechStatus.speaking);

      engine
        ..emit(TtsEvent.start)
        ..emit(TtsEvent.completion);

      expect(service.status.value, SpeechStatus.idle);
      expect(statuses, [SpeechStatus.speaking, SpeechStatus.idle]);
    },
  );

  test('a new text stops the previous one before speaking', () async {
    await service.speak('Passo 1');
    engine.emit(TtsEvent.start);
    engine.calls.clear();

    await service.speak('Passo 2');

    expect(engine.calls, ['stop', 'speak:Passo 2']);
    expect(service.status.value, SpeechStatus.speaking);
  });

  test('ignores a late completion of the replaced text', () async {
    await service.speak('Passo 1');
    engine.emit(TtsEvent.start);
    await service.speak('Passo 2');

    // Conclusão do passo 1 chegando antes do início do passo 2.
    engine.emit(TtsEvent.completion);
    expect(service.status.value, SpeechStatus.speaking);

    engine
      ..emit(TtsEvent.start)
      ..emit(TtsEvent.completion);
    expect(service.status.value, SpeechStatus.idle);
  });

  test('a text superseded during initialization is never spoken', () async {
    engine.initializeGate = Completer<void>();

    final first = service.speak('Passo 1');
    final second = service.speak('Passo 2');
    engine.initializeGate!.complete();
    await Future.wait([first, second]);

    expect(engine.spoken, ['Passo 2']);
  });

  test('pause interrupts the reading and ignores later events', () async {
    await service.speak('Passo 1');
    engine.emit(TtsEvent.start);

    await service.pause();

    expect(engine.calls.last, 'pause');
    expect(service.status.value, SpeechStatus.paused);

    engine.emit(TtsEvent.completion);
    expect(service.status.value, SpeechStatus.paused);
  });

  test('speaking after a pause restarts with the new text', () async {
    await service.speak('Passo 1');
    await service.pause();
    engine.calls.clear();

    await service.speak('Passo 1');

    expect(engine.calls, ['stop', 'speak:Passo 1']);
    expect(service.status.value, SpeechStatus.speaking);
  });

  test('pause falls back to stop when the engine cannot pause', () async {
    engine.pauseResult = false;
    await service.speak('Passo 1');

    await service.pause();

    expect(engine.calls.sublist(engine.calls.length - 2), ['pause', 'stop']);
    expect(service.status.value, SpeechStatus.idle);
  });

  test('pause while the engine is still starting the text', () async {
    engine.speakGate = Completer<void>();
    final speaking = service.speak('Passo 1');
    await pumpEventQueue();

    final pausing = service.pause();
    engine.speakGate!.complete();
    await Future.wait([speaking, pausing]);

    expect(engine.calls.last, 'pause');
    expect(service.status.value, SpeechStatus.paused);
  });

  test('pause does nothing when nothing is being read', () async {
    await service.pause();

    expect(engine.calls, isEmpty);
    expect(service.status.value, SpeechStatus.idle);
  });

  test('stop interrupts the reading and ignores later events', () async {
    await service.speak('Passo 1');
    engine.emit(TtsEvent.start);

    await service.stop();

    expect(engine.calls.last, 'stop');
    expect(service.status.value, SpeechStatus.idle);

    engine.emit(TtsEvent.start);
    expect(service.status.value, SpeechStatus.idle);
  });

  test('stop before any reading does not touch the engine', () async {
    await service.stop();

    expect(engine.calls, isEmpty);
  });

  test('stop during initialization cancels the pending text', () async {
    engine.initializeGate = Completer<void>();

    final speaking = service.speak('Passo 1');
    await service.stop();
    engine.initializeGate!.complete();
    await speaking;

    expect(engine.spoken, isEmpty);
    expect(service.status.value, SpeechStatus.idle);
  });

  test('an empty text stops the current reading', () async {
    await service.speak('Passo 1');

    await service.speak('   ');

    expect(engine.calls.last, 'stop');
    expect(engine.spoken, ['Passo 1']);
    expect(service.status.value, SpeechStatus.idle);
  });

  test('an engine error ends the reading', () async {
    await service.speak('Passo 1');

    engine.emit(TtsEvent.error);

    expect(service.status.value, SpeechStatus.idle);
  });

  test('missing speech engine throws a domain failure', () async {
    engine.hasEngine = false;

    await expectLater(
      service.speak('Passo 1'),
      throwsA(isA<SpeechEngineUnavailableFailure>()),
    );
    expect(engine.spoken, isEmpty);
    expect(service.status.value, SpeechStatus.idle);
  });

  test('missing Portuguese voice throws a domain failure', () async {
    engine.languageAvailable = false;

    await expectLater(
      service.speak('Passo 1'),
      throwsA(
        isA<SpeechLanguageUnavailableFailure>().having(
          (f) => f.language,
          'language',
          'pt-BR',
        ),
      ),
    );
    expect(engine.spoken, isEmpty);
  });

  for (final error in [
    MissingPluginException('flutter_tts'),
    PlatformException(code: 'tts'),
  ]) {
    test('${error.runtimeType} becomes an unavailable failure', () async {
      engine.initializeError = error;

      await expectLater(
        service.speak('Passo 1'),
        throwsA(
          isA<SpeechEngineUnavailableFailure>().having(
            (f) => f.cause,
            'cause',
            error,
          ),
        ),
      );
    });
  }

  test('an engine that never initializes times out', () async {
    engine.initializeGate = Completer<void>();

    await expectLater(
      service.speak('Passo 1'),
      throwsA(
        isA<SpeechEngineUnavailableFailure>().having(
          (f) => f.cause,
          'cause',
          isA<TimeoutException>(),
        ),
      ),
    );
  });

  test('a failed initialization is retried on the next reading', () async {
    engine.hasEngine = false;
    await expectLater(service.speak('Passo 1'), throwsA(isA<SpeechFailure>()));

    engine.hasEngine = true;
    await service.speak('Passo 1');

    expect(engine.calls.where((c) => c == 'initialize'), hasLength(2));
    expect(engine.spoken, ['Passo 1']);
  });

  test('text rejected by the engine throws a playback failure', () async {
    engine.speakResult = false;

    await expectLater(
      service.speak('Passo 1'),
      throwsA(isA<SpeechPlaybackFailure>()),
    );
    expect(service.status.value, SpeechStatus.idle);
  });

  test('an engine that stops answering is initialized again', () async {
    engine.speakGate = Completer<void>();

    await expectLater(
      service.speak('Passo 1'),
      throwsA(isA<SpeechEngineUnavailableFailure>()),
    );
    expect(service.status.value, SpeechStatus.idle);

    engine.speakGate = null;
    await service.speak('Passo 2');

    expect(engine.calls.where((c) => c == 'initialize'), hasLength(2));
  });

  test('going to the background stops the reading', () async {
    await service.speak('Passo 1');

    // O motor do Flutter envia cada estado intermediário até `hidden`.
    binding
      ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
      ..handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    addTearDown(
      () => binding
        ..handleAppLifecycleStateChanged(AppLifecycleState.inactive)
        ..handleAppLifecycleStateChanged(AppLifecycleState.resumed),
    );
    await pumpEventQueue();

    expect(engine.calls.last, 'stop');
    expect(service.status.value, SpeechStatus.idle);
  });

  test('dispose stops the reading', () async {
    final disposable = DeviceSpeechService(engine: engine);
    await disposable.speak('Passo 1');

    await disposable.dispose();

    expect(engine.calls.last, 'stop');
  });

  group('FlutterTtsEngine', () {
    const channel = MethodChannel('flutter_tts');
    late List<MethodCall> methodCalls;
    late Map<String, Object?> results;

    setUp(() {
      methodCalls = [];
      results = {};
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        methodCalls.add(call);
        return results[call.method] ?? 1;
      });
    });

    tearDown(
      () => binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );

    Future<void> sendEvent(String method) =>
        binding.defaultBinaryMessenger.handlePlatformMessage(
          channel.name,
          channel.codec.encodeMethodCall(MethodCall(method)),
          (_) {},
        );

    test('on Android, requires an installed engine', () async {
      final ttsEngine = FlutterTtsEngine(platform: TargetPlatform.android);

      results['getEngines'] = ['com.google.android.tts'];
      expect(await ttsEngine.initialize(), isTrue);

      results['getEngines'] = <String>[];
      expect(await ttsEngine.initialize(), isFalse);
    });

    test('on Android, rebinds the engine when initializing again', () async {
      final ttsEngine = FlutterTtsEngine(platform: TargetPlatform.android);
      results
        ..['getEngines'] = <String>[]
        ..['getDefaultEngine'] = 'com.google.android.tts';

      // Sem motor na abertura do app: o TextToSpeech nativo falha.
      expect(await ttsEngine.initialize(), isFalse);
      expect(methodCalls.map((c) => c.method), ['getEngines']);

      results['getEngines'] = ['com.example.tts', 'com.google.android.tts'];
      methodCalls.clear();
      expect(await ttsEngine.initialize(), isTrue);

      expect(methodCalls.map((c) => c.method), [
        'getEngines',
        'getDefaultEngine',
        'setEngine',
      ]);
      expect(methodCalls.last.arguments, 'com.google.android.tts');
    });

    test('on Android, rebinds the first engine without a default', () async {
      final ttsEngine = FlutterTtsEngine(platform: TargetPlatform.android);
      results
        ..['getEngines'] = ['com.example.tts']
        ..['getDefaultEngine'] = null;

      await ttsEngine.initialize();
      await ttsEngine.initialize();

      expect(methodCalls.last.method, 'setEngine');
      expect(methodCalls.last.arguments, 'com.example.tts');
    });

    test('on iOS, shares the audio session', () async {
      final ttsEngine = FlutterTtsEngine(platform: TargetPlatform.iOS);

      expect(await ttsEngine.initialize(), isTrue);
      // O plugin só envia a categoria de áudio quando o host é iOS de fato.
      expect(methodCalls.first.method, 'setSharedInstance');
      expect(methodCalls.first.arguments, isTrue);
    });

    test('other platforms have no engine', () async {
      final ttsEngine = FlutterTtsEngine(platform: TargetPlatform.windows);

      expect(await ttsEngine.initialize(), isFalse);
      expect(methodCalls, isEmpty);
    });

    test('maps plugin results to booleans', () async {
      final ttsEngine = FlutterTtsEngine(platform: TargetPlatform.android);

      expect(await ttsEngine.setLanguage('pt-BR'), isTrue);
      expect(await ttsEngine.speak('Olá'), isTrue);
      expect(await ttsEngine.pause(), isTrue);
      await ttsEngine.setSpeechRate(0.5);
      await ttsEngine.setPitch(1.0);
      await ttsEngine.stop();

      results
        ..['setLanguage'] = 0
        ..['speak'] = 0
        ..['pause'] = 0;
      expect(await ttsEngine.setLanguage('pt-BR'), isFalse);
      expect(await ttsEngine.speak('Olá'), isFalse);
      expect(await ttsEngine.pause(), isFalse);

      expect(
        methodCalls.map((c) => c.method),
        containsAll(['setSpeechRate', 'setPitch', 'stop']),
      );
    });

    test('forwards plugin events', () async {
      final ttsEngine = FlutterTtsEngine(platform: TargetPlatform.android);
      final events = <TtsEvent>[];
      ttsEngine.setEventHandler(events.add);
      await ttsEngine.stop();

      await sendEvent('speak.onStart');
      await sendEvent('speak.onContinue');
      await sendEvent('speak.onComplete');
      await binding.defaultBinaryMessenger.handlePlatformMessage(
        channel.name,
        channel.codec.encodeMethodCall(
          const MethodCall('speak.onError', 'falhou'),
        ),
        (_) {},
      );

      expect(events, [
        TtsEvent.start,
        TtsEvent.start,
        TtsEvent.completion,
        TtsEvent.error,
      ]);
    });
  });
}
