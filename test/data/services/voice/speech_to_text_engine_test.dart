import 'package:flutter_test/flutter_test.dart';
import 'package:o_que_comer_app/data/services/voice/speech_to_text_engine.dart';
import 'package:o_que_comer_app/data/services/voice/voice_recognition_engine.dart';
import 'package:o_que_comer_app/domain/models/voice_failure.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

class _Speech extends Fake implements SpeechToText {
  SpeechStatusListener? status;
  SpeechErrorListener? error;
  SpeechResultListener? result;
  SpeechSoundLevelChange? soundLevel;
  SpeechListenOptions? options;
  List<SpeechConfigOption>? config;
  Object? listenError;
  bool? logging;
  int cancellations = 0;

  @override
  Future<bool> initialize({
    SpeechErrorListener? onError,
    SpeechStatusListener? onStatus,
    dynamic debugLogging = false,
    Duration finalTimeout = SpeechToText.defaultFinalTimeout,
    List<SpeechConfigOption>? options,
  }) async {
    status = onStatus;
    error = onError;
    config = options;
    logging = debugLogging as bool;
    return true;
  }

  @override
  Future<List<LocaleName>> locales() async => [
    LocaleName('pt_BR', 'Português'),
  ];

  @override
  Future<void> listen({
    SpeechResultListener? onResult,
    Duration? listenFor,
    Duration? pauseFor,
    String? localeId,
    SpeechSoundLevelChange? onSoundLevelChange,
    dynamic cancelOnError = false,
    dynamic partialResults = true,
    dynamic onDevice = false,
    ListenMode listenMode = ListenMode.confirmation,
    dynamic sampleRate = 0,
    SpeechListenOptions? listenOptions,
  }) async {
    if (listenError != null) {
      Error.throwWithStackTrace(listenError!, StackTrace.current);
    }
    result = onResult;
    soundLevel = onSoundLevelChange;
    options = listenOptions;
  }

  @override
  Future<void> cancel() async {
    cancellations++;
  }
}

void main() {
  late _Speech speech;
  late SpeechToTextEngine engine;
  setUp(() {
    speech = _Speech();
    engine = SpeechToTextEngine(speech: speech);
  });

  test(
    'configura reconhecimento de comandos sem Bluetooth nem logs de áudio',
    () async {
      final states = <VoiceEngineStatus>[];
      final errors = <String>[];
      expect(
        await engine.initialize(onStatus: states.add, onError: errors.add),
        isTrue,
      );
      expect(speech.logging, isFalse);
      expect(speech.config!.single, SpeechToText.androidNoBluetooth);
      for (final status in [
        'listening',
        'notListening',
        'done',
        'desconhecido',
      ]) {
        speech.status!(status);
      }
      expect(states, VoiceEngineStatus.values);
      speech.error!(SpeechRecognitionError('error_no_match', false));
      expect(errors, ['error_no_match']);
      expect(await engine.locales(), ['pt_BR']);
    },
  );

  test(
    'acompanha a fala com parciais e repassa o indicador de resultado final',
    () async {
      final words = <String>[];
      final levels = <double>[];
      engine = SpeechToTextEngine(speech: speech, onSoundLevel: levels.add);
      await engine.listen(
        localeId: 'pt_BR',
        onResult: (text, {required isFinal}) => words.add('$text/$isFinal'),
      );
      final options = speech.options!;
      expect(options.localeId, 'pt_BR');
      expect(options.listenMode, ListenMode.confirmation);
      expect(options.partialResults, isTrue);
      expect(options.pauseFor, const Duration(seconds: 2));
      expect(options.cancelOnError, isTrue);
      expect(options.onDevice, isFalse);
      expect(options.autoPunctuation, isFalse);
      speech.soundLevel!(12.5);
      expect(levels, [12.5]);
      speech.result!(
        SpeechRecognitionResult.init([
          const SpeechRecognitionWords('próximo', null, 1),
        ], ResultType.partial),
      );
      speech.result!(
        SpeechRecognitionResult.init([
          const SpeechRecognitionWords('próximo', null, 1),
        ], ResultType.finalResult),
      );
      expect(words, ['próximo/false', 'próximo/true']);
      await engine.cancel();
      expect(speech.cancellations, 1);
    },
  );

  for (final error in [
    SpeechToTextNotInitializedException(),
    ListenFailedException('x', null, null),
    ListenNotStartedException(),
  ]) {
    test('converte ${error.runtimeType} em falha de domínio', () async {
      speech.listenError = error;
      await expectLater(
        engine.listen(localeId: 'pt_BR', onResult: (_, {required isFinal}) {}),
        throwsA(isA<VoiceFailure>()),
      );
    });
  }
}
