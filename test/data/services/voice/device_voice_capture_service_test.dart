import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:o_que_comer_app/data/services/errors/error_reporter.dart';
import 'package:o_que_comer_app/data/services/voice/device_voice_capture_service.dart';
import 'package:o_que_comer_app/data/services/voice/voice_capture_service.dart';
import 'package:o_que_comer_app/data/services/voice/voice_recognition_engine.dart';
import 'package:o_que_comer_app/domain/models/app_permission.dart';
import 'package:o_que_comer_app/domain/models/voice_failure.dart';

import '../../../../testing/voice_test_clock.dart';
import '../../../../testing/fakes/fake_voice_permissions.dart';
import '../../../../testing/fakes/fake_voice_recognition_engine.dart';

class _Reporter implements ErrorReporter {
  final errors = <Object>[];
  bool fail = false;
  @override
  Future<void> recordError(
    Object error,
    StackTrace stackTrace, {
    String? reason,
    bool fatal = false,
  }) async {
    errors.add(error);
    if (fail) throw StateError('reporter unavailable');
  }
}

void main() {
  late FakeVoiceRecognitionEngine engine;
  late FakeVoicePermissions permissions;
  late _Reporter reporter;
  late DeviceVoiceCaptureService service;
  late List<String> texts;
  late List<VoiceFailure> failures;
  late List<StreamSubscription<Object?>> subscriptions;

  void initialize() {
    engine = FakeVoiceRecognitionEngine();
    permissions = FakeVoicePermissions();
    reporter = _Reporter();
    service = DeviceVoiceCaptureService(
      engine: engine,
      permissions: permissions,
      errorReporter: reporter,
      restartDelay: const Duration(milliseconds: 100),
      finalResultWait: const Duration(seconds: 3),
      startTimeout: const Duration(seconds: 5),
    );
    texts = [];
    failures = [];
    subscriptions = [
      service.transcripts.listen(texts.add),
      service.failures.listen(failures.add),
    ];
  }

  void voiceTest(
    String description,
    Future<void> Function(VoiceTestClock) body,
  ) {
    testWithVoiceClock(description, (tester) async {
      initialize();
      try {
        await body(tester);
      } finally {
        engine.cancelError = null;
        final disposing = service.dispose();
        await tester.pump();
        await disposing;
        for (final subscription in subscriptions) {
          unawaited(subscription.cancel());
        }
      }
    });
  }

  voiceTest('construção não inicializa nem pede permissão', (_) async {
    expect(engine.initializeCalls, 0);
    expect(permissions.checks, isEmpty);
    expect(service.state, VoiceCaptureState.stopped);
  });

  voiceTest('inicia pt-BR, ignora parciais e entrega um final por sessão', (
    tester,
  ) async {
    await service.start();
    await service.start();
    expect(engine.initializeCalls, 1);
    expect(engine.listenCalls, 1);
    expect(engine.lastLocale, 'pt_BR');
    expect(service.state, VoiceCaptureState.listening);
    engine.result('próximo', isFinal: false);
    engine.result(' ');
    engine.result('próximo passo');
    engine.result('próximo passo');
    await tester.pump();
    expect(texts, ['próximo passo']);
    await service.stop();
    await service.start();
    expect(engine.initializeCalls, 1);
  });

  for (final access in [
    PermissionAccess.denied,
    PermissionAccess.permanentlyDenied,
    PermissionAccess.restricted,
  ]) {
    voiceTest('microfone $access é distinto de indisponibilidade', (
      tester,
    ) async {
      permissions.access[AppPermission.microphone] = access;
      permissions.requestedAccess = access;
      await service.start();
      await tester.pump();
      expect(failures.single.kind, VoiceFailureKind.microphoneDenied);
      expect(failures.single.permissionAccess, access);
      expect(
        failures.single.canOpenSettings,
        access != PermissionAccess.denied,
      );
      expect(service.state, VoiceCaptureState.failed);
      expect(engine.initializeCalls, 0);
      expect(
        permissions.requests,
        access == PermissionAccess.denied
            ? [AppPermission.microphone]
            : isEmpty,
      );
      expect(reporter.errors, isEmpty);
    });
  }

  voiceTest('microfone concedido após solicitação permite escutar', (
    tester,
  ) async {
    permissions.access[AppPermission.microphone] = PermissionAccess.denied;
    await service.start();
    expect(permissions.requests, [AppPermission.microphone]);
    expect(service.state, VoiceCaptureState.listening);
  });

  voiceTest('autorização de fala do iOS negada tem erro próprio', (
    tester,
  ) async {
    permissions.access[AppPermission.speechRecognition] =
        PermissionAccess.permanentlyDenied;
    await service.start();
    await tester.pump();
    expect(failures.single.kind, VoiceFailureKind.speechPermissionDenied);
    expect(failures.single.canOpenSettings, isTrue);
    expect(engine.initializeCalls, 0);
  });

  voiceTest('motor indisponível não tenta escutar', (tester) async {
    engine.available = false;
    await service.start();
    await tester.pump();
    expect(failures.single.kind, VoiceFailureKind.recognitionUnavailable);
    expect(engine.listenCalls, 0);
    expect(reporter.errors, isEmpty);
  });

  voiceTest('não troca silenciosamente para outro idioma', (tester) async {
    engine.supportedLocales = ['en_US', 'pt_PT'];
    await service.start();
    await tester.pump();
    expect(failures.single.kind, VoiceFailureKind.languageUnavailable);
    expect(engine.listenCalls, 0);
  });

  voiceTest('aceita o identificador pt-BR usado no iOS', (tester) async {
    engine.supportedLocales = ['pt-BR'];
    await service.start();
    expect(engine.lastLocale, 'pt-BR');
  });

  voiceTest('aguarda resultado final após notListening e reinicia em done', (
    tester,
  ) async {
    await service.start();
    engine.status(VoiceEngineStatus.notListening);
    await tester.pump(const Duration(seconds: 1));
    expect(engine.listenCalls, 1);
    engine.result('avançar');
    engine.status(VoiceEngineStatus.done);
    await tester.pump(const Duration(milliseconds: 101));
    engine.result('parar', session: 0);
    engine.result('avançar');
    await tester.pump();
    expect(texts, ['avançar', 'avançar']);
    expect(engine.listenCalls, 2);
  });

  voiceTest('motor que omite done também é reiniciado', (tester) async {
    await service.start();
    engine.status(VoiceEngineStatus.notListening);
    await tester.pump(const Duration(seconds: 3));
    expect(engine.listenCalls, 2);
  });

  voiceTest('cada frase final rearma a captura mesmo sem status done', (
    tester,
  ) async {
    await service.start();
    for (final phrase in [
      'próximo passo',
      'continuar',
      'parar',
      'passo anterior',
    ]) {
      engine.result(phrase);
      engine.result(phrase);
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(texts, ['próximo passo', 'continuar', 'parar', 'passo anterior']);
    expect(engine.listenCalls, 5);
    expect(failures, isEmpty);
  });

  voiceTest('resultado final após done ainda é entregue antes de rearmar', (
    tester,
  ) async {
    await service.start();
    engine.result('continu', isFinal: false);
    engine.status(VoiceEngineStatus.notListening);
    engine.status(VoiceEngineStatus.done);
    await tester.pump(const Duration(seconds: 1));
    engine.result('continuar');
    await tester.pump(const Duration(milliseconds: 100));
    expect(texts, ['continuar']);
    expect(engine.listenCalls, 2);
    expect(failures, isEmpty);
  });

  voiceTest('erro após done não é confundido com ausência de fala', (
    tester,
  ) async {
    await service.start();
    engine.status(VoiceEngineStatus.notListening);
    engine.status(VoiceEngineStatus.done);
    engine.error('error_network');
    await tester.pump();
    expect(failures.single.kind, VoiceFailureKind.engine);
    await tester.pump(const Duration(milliseconds: 100));
    expect(engine.listenCalls, 2);
  });

  voiceTest('sessão concluída sem resultado relata silêncio e retoma', (
    tester,
  ) async {
    await service.start();
    engine.status(VoiceEngineStatus.done);
    await tester.pump();
    expect(failures, isEmpty);
    await tester.pump(const Duration(seconds: 3));
    expect(failures.single.kind, VoiceFailureKind.noSpeech);
    expect(engine.listenCalls, 2);
    expect(texts, isEmpty);
  });

  voiceTest('falha de um início cancelado não derruba uma nova ativação', (
    tester,
  ) async {
    final pending = Completer<bool>();
    engine.pendingInitialization = pending;
    final oldStart = service.start();
    await tester.pump();
    final stopping = service.stop();
    final newStart = service.start();
    engine.pendingInitialization = null;
    pending.completeError(StateError('início antigo'));
    await oldStart;
    await stopping;
    await newStart;
    await tester.pump();
    expect(service.state, VoiceCaptureState.listening);
    expect(failures, isEmpty);
    expect(reporter.errors, isEmpty);
    expect(engine.listenCalls, 1);
  });

  voiceTest('assinatura pausada não impede desligar e descartar o serviço', (
    tester,
  ) async {
    await service.start();
    final paused = service.transcripts.listen((_) {});
    paused.pause();
    await service.dispose();
    expect(service.state, VoiceCaptureState.stopped);
    unawaited(paused.cancel());
  });

  for (final code in ['error_no_match', 'error_speech_timeout']) {
    voiceTest('$code é tratável e mantém intervalo fixo entre sessões', (
      tester,
    ) async {
      await service.start();
      engine.error(code);
      await tester.pump();
      expect(failures.single.kind, VoiceFailureKind.noSpeech);
      await tester.pump(const Duration(milliseconds: 100));
      expect(engine.listenCalls, 2);
      engine.error(code);
      await tester.pump(const Duration(milliseconds: 100));
      expect(engine.listenCalls, 3);
      engine.error(code);
      await tester.pump(const Duration(milliseconds: 100));
      expect(engine.listenCalls, 4);
      expect(reporter.errors, isEmpty);
    });
  }

  voiceTest(
    'falhas persistentes têm limite de tentativas e permitem reinício manual',
    (tester) async {
      await service.start();
      for (var retry = 1; retry <= 4; retry++) {
        engine.error('error_network');
        await tester.pump(Duration(milliseconds: retry * 100));
      }
      expect(service.state, VoiceCaptureState.failed);
      expect(engine.listenCalls, 4);
      expect(failures.every((f) => f.kind == VoiceFailureKind.engine), isTrue);
      expect(reporter.errors, isEmpty);
      await service.start();
      expect(service.state, VoiceCaptureState.listening);
    },
  );

  voiceTest('listen sem confirmação do motor não fica preso em starting', (
    tester,
  ) async {
    engine.emitListening = false;
    await service.start();
    expect(service.state, VoiceCaptureState.starting);
    await tester.pump(const Duration(seconds: 5));
    expect(failures.single.kind, VoiceFailureKind.engine);
    expect(service.state, VoiceCaptureState.restarting);
  });

  voiceTest(
    'uma sessão com silêncio interrompe a sequência de falhas do motor',
    (tester) async {
      await service.start();
      engine.error('error_network');
      await tester.pump(const Duration(milliseconds: 100));
      engine.error('error_no_match');
      await tester.pump(const Duration(milliseconds: 100));
      for (var retry = 1; retry <= 3; retry++) {
        engine.error('error_network');
        await tester.pump(Duration(milliseconds: retry * 100));
      }
      expect(service.state, VoiceCaptureState.listening);
      expect(engine.listenCalls, 6);
    },
  );

  for (final entry in {
    'error_permission': VoiceFailureKind.microphoneDenied,
    'error_language_not_supported': VoiceFailureKind.languageUnavailable,
    'error_speech_recognizer_disabled': VoiceFailureKind.recognitionUnavailable,
  }.entries) {
    voiceTest('${entry.key} interrompe tentativas automáticas', (tester) async {
      await service.start();
      engine.error(entry.key);
      await tester.pump();
      expect(failures.single.kind, entry.value);
      await tester.pump(const Duration(seconds: 10));
      expect(engine.listenCalls, 1);
      expect(service.state, VoiceCaptureState.failed);
    });
  }

  voiceTest(
    'erro inesperado é sanitizado e falha do reporter não causa crash',
    (tester) async {
      reporter.fail = true;
      engine.initializeError = StateError('transcrição sensível');
      await service.start();
      await tester.pump();
      expect(failures.single.kind, VoiceFailureKind.unexpected);
      expect(reporter.errors.single.toString(), isNot(contains('sensível')));
      engine.initializeError = null;
      await service.start();
      engine.error('erro com dados sensíveis');
      await tester.pump();
      expect(reporter.errors.length, 2);
      expect(reporter.errors.join(), isNot(contains('sensíveis')));
    },
  );

  voiceTest('plugin ausente é indisponibilidade esperada', (tester) async {
    engine.initializeError = MissingPluginException();
    await service.start();
    await tester.pump();
    expect(failures.single.kind, VoiceFailureKind.recognitionUnavailable);
    expect(reporter.errors, isEmpty);
  });

  voiceTest('stop cancela reinício e descarta resultados atrasados', (
    tester,
  ) async {
    await service.start();
    engine.status(VoiceEngineStatus.done);
    await service.stop();
    engine.result('próximo');
    engine.error('error_network');
    await tester.pump(const Duration(seconds: 10));
    expect(engine.listenCalls, 1);
    expect(texts, isEmpty);
    expect(service.state, VoiceCaptureState.stopped);
  });

  voiceTest('stop durante inicialização não liga microfone depois', (
    tester,
  ) async {
    engine.pendingInitialization = Completer<bool>();
    final starting = service.start();
    await tester.pump();
    final stopping = service.stop();
    engine.pendingInitialization!.complete(true);
    await starting;
    await stopping;
    expect(engine.listenCalls, 0);
    expect(service.state, VoiceCaptureState.stopped);
  });

  voiceTest('leitura cancela antes de tocar e ignora a própria fala', (
    tester,
  ) async {
    await service.start();
    final audio = Completer<String>();
    final reading = service.duringPlayback(() {
      expect(service.state, VoiceCaptureState.suspended);
      engine.result('próximo passo');
      engine.status(VoiceEngineStatus.done);
      return audio.future;
    });
    await tester.pump(const Duration(seconds: 10));
    expect(texts, isEmpty);
    expect(engine.listenCalls, 1);
    audio.complete('concluído');
    expect(await reading, 'concluído');
    expect(engine.listenCalls, 2);
    engine.result('continuar');
    await tester.pump();
    expect(texts, ['continuar']);
  });

  voiceTest('leituras sobrepostas só retomam após a última terminar', (
    tester,
  ) async {
    await service.start();
    final first = Completer<void>(), second = Completer<void>();
    final a = service.duringPlayback(() => first.future);
    final b = service.duringPlayback(() => second.future);
    await tester.pump();
    first.complete();
    await a;
    expect(engine.listenCalls, 1);
    second.complete();
    await b;
    expect(engine.listenCalls, 2);
  });

  voiceTest(
    'stop durante leitura impede retomada e erro de áudio libera suspensão',
    (tester) async {
      await service.start();
      final audio = Completer<void>();
      final reading = service.duringPlayback(() => audio.future);
      await tester.pump();
      await service.stop();
      audio.complete();
      await reading;
      expect(engine.listenCalls, 1);
      await service.start();
      await expectLater(
        service.duringPlayback<void>(() async => throw StateError('áudio')),
        throwsStateError,
      );
      expect(service.state, VoiceCaptureState.listening);
    },
  );

  voiceTest('não toca áudio quando cancelamento do motor falha', (
    tester,
  ) async {
    await service.start();
    engine.cancelError = StateError('cancel');
    var played = false;
    await expectLater(
      service.duringPlayback(() async {
        played = true;
      }),
      throwsA(isA<VoiceFailure>()),
    );
    expect(played, isFalse);
    expect(service.state, VoiceCaptureState.failed);
  });

  voiceTest(
    'dispose fecha streams e impede comandos, reinícios e retomada de leitura',
    (tester) async {
      await service.start();
      final audio = Completer<void>();
      final reading = service.duringPlayback(() => audio.future);
      await tester.pump();
      await service.dispose();
      audio.complete();
      await reading;
      await service.dispose();
      await service.start();
      engine.result('avançar');
      await tester.pump(const Duration(seconds: 10));
      expect(texts, isEmpty);
      expect(engine.listenCalls, 1);
      await expectLater(
        service.duringPlayback(() async {}),
        throwsA(isA<VoiceFailure>()),
      );
    },
  );
}
