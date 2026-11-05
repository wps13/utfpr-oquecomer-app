import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:o_que_comer_app/data/services/errors/error_reporter.dart';
import 'package:o_que_comer_app/data/services/screen_wake_lock/screen_wake_lock_service.dart';
import 'package:o_que_comer_app/data/services/voice/device_voice_capture_service.dart';
import 'package:o_que_comer_app/data/services/voice/voice_capture_service.dart';
import 'package:o_que_comer_app/data/services/voice/voice_recognition_engine.dart';
import 'package:o_que_comer_app/domain/models/voice_command.dart';
import 'package:o_que_comer_app/domain/models/voice_failure.dart';
import 'package:o_que_comer_app/ui/hands_free_mode/view_models/voice_commands_viewmodel.dart';

import '../../../../testing/voice_test_clock.dart';
import '../../../../testing/fakes/fake_voice_permissions.dart';
import '../../../../testing/fakes/fake_voice_recognition_engine.dart';

class _FakeScreenWakeLockService implements ScreenWakeLockService {
  int enableCalls = 0;
  int disableCalls = 0;

  @override
  Future<void> enable() async => enableCalls++;

  @override
  Future<void> disable() async => disableCalls++;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeVoiceRecognitionEngine engine;
  late DeviceVoiceCaptureService capture;
  late VoiceCommandsViewModel vm;
  late _FakeScreenWakeLockService wakeLock;
  late List<VoiceCommand> commands;
  late StreamSubscription<VoiceCommand> subscription;
  var disposed = false;

  void initialize() {
    disposed = false;
    engine = FakeVoiceRecognitionEngine();
    capture = DeviceVoiceCaptureService(
      engine: engine,
      permissions: FakeVoicePermissions(),
      errorReporter: const DisabledErrorReporter(),
    );
    wakeLock = _FakeScreenWakeLockService();
    vm = VoiceCommandsViewModel(capture: capture, wakeLock: wakeLock);
    commands = [];
    subscription = vm.commands.listen(commands.add);
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
        if (!disposed) vm.dispose();
        unawaited(subscription.cancel());
        final disposing = capture.dispose();
        await tester.pump();
        await disposing;
      }
    });
  }

  voiceTest('não pede microfone ao criar a ViewModel', (tester) async {
    expect(vm.state, VoiceCaptureState.stopped);
    expect(engine.initializeCalls, 0);
    await vm.start();
    await tester.pump();
    expect(vm.state, VoiceCaptureState.listening);
  });

  voiceTest('interpreta frases finais e ignora texto livre', (tester) async {
    await vm.start();
    engine.result('receita de bolo');
    await tester.pump();
    expect(commands, isEmpty);
    await vm.stop();
    await vm.start();
    engine.result('PRÓXIMO PASSO!');
    await tester.pump();
    expect(commands, [VoiceCommand.nextStep]);
  });

  voiceTest('parar pausa a leitura sem desligar a captura de continuar', (
    tester,
  ) async {
    await vm.start();
    engine.result('parar');
    await tester.pump();
    expect(commands, [VoiceCommand.pause]);
    expect(capture.state, VoiceCaptureState.restarting);
    engine.status(VoiceEngineStatus.done);
    await tester.pump(const Duration(milliseconds: 400));
    engine.result('continuar');
    await tester.pump();
    expect(commands, [VoiceCommand.pause, VoiceCommand.resume]);
  });

  for (final phrase in ['sair', 'sair do modo']) {
    voiceTest('$phrase emite a intenção e encerra escuta', (tester) async {
      await vm.start();
      engine.result(phrase);
      await tester.pump();
      expect(
        commands.single,
        phrase == 'sair' ? VoiceCommand.exit : VoiceCommand.exitMode,
      );
      expect(capture.state, VoiceCaptureState.stopped);
      engine.result('próximo');
      await tester.pump(const Duration(seconds: 10));
      expect(commands, hasLength(1));
      expect(engine.listenCalls, 1);
    });
  }

  voiceTest('erro do motor fica disponível para a tela', (tester) async {
    engine.available = false;
    await vm.start();
    await tester.pump();
    expect(vm.failure?.kind, VoiceFailureKind.recognitionUnavailable);
    expect(vm.state, VoiceCaptureState.failed);
    engine.available = true;
    await vm.start();
    await tester.pump();
    expect(vm.failure, isNull);
    expect(vm.state, VoiceCaptureState.listening);
  });

  voiceTest(
    'recebe os seis comandos em sessões sucessivas sem parar após o primeiro',
    (tester) async {
      await vm.start();
      for (final phrase in [
        'continuar',
        'parar',
        'próximo passo',
        'passo anterior',
      ]) {
        engine.result(phrase);
        await tester.pump(const Duration(milliseconds: 400));
      }
      engine.result('sair');
      await tester.pump();
      expect(capture.state, VoiceCaptureState.stopped);
      await vm.start();
      engine.result('sair do modo');
      await tester.pump();
      expect(commands, VoiceCommand.values);
      expect(capture.state, VoiceCaptureState.stopped);
    },
  );

  voiceTest('não interpreta leitura e só retoma quando ela termina', (
    tester,
  ) async {
    await vm.start();
    final audio = Completer<void>();
    final reading = vm.duringPlayback(() => audio.future);
    await tester.pump();
    engine.result('avançar');
    await tester.pump();
    expect(commands, isEmpty);
    expect(vm.state, VoiceCaptureState.suspended);
    audio.complete();
    await reading;
    engine.result('avançar');
    await tester.pump();
    expect(commands, [VoiceCommand.nextStep]);
  });

  for (final lifecycle in [
    AppLifecycleState.paused,
    AppLifecycleState.hidden,
    AppLifecycleState.detached,
  ]) {
    voiceTest('$lifecycle interrompe e não retoma sozinho', (tester) async {
      await vm.start();
      vm.didChangeAppLifecycleState(lifecycle);
      await tester.pump();
      expect(capture.state, VoiceCaptureState.stopped);
      vm.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await tester.pump(const Duration(seconds: 10));
      expect(engine.listenCalls, 1);
    });
  }

  voiceTest('inactive durante autorização não cancela o início', (
    tester,
  ) async {
    engine.pendingInitialization = Completer<bool>();
    final starting = vm.start();
    await tester.pump();
    vm.didChangeAppLifecycleState(AppLifecycleState.inactive);
    engine.pendingInitialization!.complete(true);
    await starting;
    expect(capture.state, VoiceCaptureState.listening);
  });

  voiceTest('descartar a tela para captura e ignora callbacks posteriores', (
    tester,
  ) async {
    await vm.start();
    var notifications = 0;
    vm.addListener(() => notifications++);
    vm.dispose();
    disposed = true;
    engine.result('avançar');
    await tester.pump(const Duration(seconds: 10));
    expect(capture.state, VoiceCaptureState.stopped);
    expect(commands, isEmpty);
    expect(notifications, 0);
    await vm.start();
    expect(engine.listenCalls, 1);
  });
}
