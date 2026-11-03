import '../../../domain/models/voice_failure.dart';

enum VoiceCaptureState {
  stopped,
  starting,
  listening,
  suspended,
  restarting,
  failed,
}

abstract interface class VoiceCaptureService {
  Stream<String> get transcripts;
  Stream<VoiceFailure> get failures;
  Stream<VoiceCaptureState> get states;
  VoiceCaptureState get state;

  /// Somente após ação explícita de uso. Não é chamado ao abrir o app.
  Future<void> start();
  Future<void> stop();

  /// [playback] deve terminar somente quando o áudio efetivamente terminar.
  /// Cancela a captura antes de tocar; suporta leituras sobrepostas e stop().
  Future<T> duringPlayback<T>(Future<T> Function() playback);

  Future<void> dispose();
}
