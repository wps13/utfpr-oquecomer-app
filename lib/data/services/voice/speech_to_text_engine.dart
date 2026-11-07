import 'package:speech_to_text/speech_to_text.dart';

import '../../../domain/models/voice_failure.dart';
import 'voice_recognition_engine.dart';

class SpeechToTextEngine implements VoiceRecognitionEngine {
  SpeechToTextEngine({
    SpeechToText? speech,
    void Function(double)? onSoundLevel,
  }) : _speech = speech ?? SpeechToText(),
       _soundLevelListener = onSoundLevel;

  final SpeechToText _speech;
  final void Function(double)? _soundLevelListener;

  @override
  Future<bool> initialize({
    required void Function(VoiceEngineStatus status) onStatus,
    required void Function(String code) onError,
  }) => _speech.initialize(
    debugLogging: false,
    // Bluetooth não faz parte deste card e não deve pedir outra permissão.
    options: [SpeechToText.androidNoBluetooth],
    onStatus: (status) {
      switch (status) {
        case SpeechToText.listeningStatus:
          onStatus(VoiceEngineStatus.listening);
        case SpeechToText.notListeningStatus:
          onStatus(VoiceEngineStatus.notListening);
        case SpeechToText.doneStatus:
          onStatus(VoiceEngineStatus.done);
      }
    },
    onError: (error) => onError(error.errorMsg),
  );

  @override
  Future<List<String>> locales() async =>
      (await _speech.locales()).map((locale) => locale.localeId).toList();

  @override
  Future<void> listen({
    required String localeId,
    required VoiceResultListener onResult,
  }) async {
    try {
      await _speech.listen(
        onSoundLevelChange: _soundLevelListener,
        onResult: (result) =>
            onResult(result.recognizedWords, isFinal: result.finalResult),
        listenOptions: SpeechListenOptions(
          localeId: localeId,
          listenMode: ListenMode.confirmation,
          // Mantém o relógio de silêncio atualizado durante a fala.
          // O serviço continua descartando parciais ao emitir comandos.
          partialResults: true,
          cancelOnError: true,
          onDevice: false,
          autoPunctuation: false,
          enableHapticFeedback: false,
          listenFor: const Duration(seconds: 50),
          pauseFor: const Duration(seconds: 2),
        ),
      );
    } on SpeechToTextNotInitializedException {
      throw const VoiceFailure(VoiceFailureKind.recognitionUnavailable);
    } on ListenFailedException {
      throw const VoiceFailure(VoiceFailureKind.engine);
    } on ListenNotStartedException {
      throw const VoiceFailure(VoiceFailureKind.engine);
    }
  }

  @override
  Future<void> cancel() => _speech.cancel();
}
